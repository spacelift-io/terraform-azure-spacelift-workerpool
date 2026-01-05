package spacelift

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

type Client struct {
	endpoint  string
	keyID     string
	keySecret string
	httpClient *http.Client
}

type Worker struct {
	ID         string    `json:"id"`
	InstanceID string    `json:"instanceId"`
	Status     string    `json:"status"`
	Busy       bool      `json:"busy"`
	Drained    bool      `json:"drained"`
	CreatedAt  time.Time `json:"createdAt"`
}

type WorkerPoolMetrics struct {
	SchedulableRuns int `json:"schedulableRuns"`
	ActiveWorkers   int `json:"activeWorkers"`
	IdleWorkers     int `json:"idleWorkers"`
}

func NewClient(endpoint, keyID, keySecret string) *Client {
	return &Client{
		endpoint:  endpoint,
		keyID:     keyID,
		keySecret: keySecret,
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// GetWorkerPoolMetrics retrieves metrics for a worker pool
func (c *Client) GetWorkerPoolMetrics(ctx context.Context, workerPoolID string) (*WorkerPoolMetrics, error) {
	query := `
		query GetWorkerPoolMetrics($id: ID!) {
			workerPool(id: $id) {
				schedulableRuns: schedulableRuns
				workers {
					id
					busy
					drained
				}
			}
		}
	`

	variables := map[string]interface{}{
		"id": workerPoolID,
	}

	var response struct {
		Data struct {
			WorkerPool struct {
				SchedulableRuns int `json:"schedulableRuns"`
				Workers         []struct {
					ID      string `json:"id"`
					Busy    bool   `json:"busy"`
					Drained bool   `json:"drained"`
				} `json:"workers"`
			} `json:"workerPool"`
		} `json:"data"`
	}

	if err := c.doGraphQLRequest(ctx, query, variables, &response); err != nil {
		return nil, err
	}

	metrics := &WorkerPoolMetrics{
		SchedulableRuns: response.Data.WorkerPool.SchedulableRuns,
		ActiveWorkers:   len(response.Data.WorkerPool.Workers),
	}

	// Count idle workers (not busy and not drained)
	for _, worker := range response.Data.WorkerPool.Workers {
		if !worker.Busy && !worker.Drained {
			metrics.IdleWorkers++
		}
	}

	return metrics, nil
}

// GetWorkers retrieves all workers in a worker pool
func (c *Client) GetWorkers(ctx context.Context, workerPoolID string) ([]Worker, error) {
	query := `
		query GetWorkers($id: ID!) {
			workerPool(id: $id) {
				workers {
					id
					metadata
					busy
					drained
					createdAt
				}
			}
		}
	`

	variables := map[string]interface{}{
		"id": workerPoolID,
	}

	var response struct {
		Data struct {
			WorkerPool struct {
				Workers []struct {
					ID        string                 `json:"id"`
					Metadata  map[string]interface{} `json:"metadata"`
					Busy      bool                   `json:"busy"`
					Drained   bool                   `json:"drained"`
					CreatedAt int64                  `json:"createdAt"`
				} `json:"workers"`
			} `json:"workerPool"`
		} `json:"data"`
	}

	if err := c.doGraphQLRequest(ctx, query, variables, &response); err != nil {
		return nil, err
	}

	workers := make([]Worker, 0, len(response.Data.WorkerPool.Workers))
	for _, w := range response.Data.WorkerPool.Workers {
		instanceID := ""
		if metadata := w.Metadata; metadata != nil {
			// Extract instance ID from metadata
			if id, ok := metadata["instance_id"].(string); ok {
				instanceID = id
			} else if id, ok := metadata["vm_resource_id"].(string); ok {
				// For Azure, we might use the VM resource ID
				instanceID = id
			}
		}

		worker := Worker{
			ID:         w.ID,
			InstanceID: instanceID,
			Busy:       w.Busy,
			Drained:    w.Drained,
			CreatedAt:  time.Unix(w.CreatedAt, 0),
		}

		workers = append(workers, worker)
	}

	return workers, nil
}

// GetWorker retrieves a specific worker
func (c *Client) GetWorker(ctx context.Context, workerPoolID, workerID string) (*Worker, error) {
	workers, err := c.GetWorkers(ctx, workerPoolID)
	if err != nil {
		return nil, err
	}

	for i := range workers {
		if workers[i].ID == workerID {
			return &workers[i], nil
		}
	}

	return nil, fmt.Errorf("worker %s not found", workerID)
}

// DrainWorker drains a specific worker
func (c *Client) DrainWorker(ctx context.Context, workerPoolID, workerID string) error {
	mutation := `
		mutation DrainWorker($pool: ID!, $worker: ID!) {
			workerPoolWorkerDrain(pool: $pool, worker: $worker) {
				id
				drained
			}
		}
	`

	variables := map[string]interface{}{
		"pool":   workerPoolID,
		"worker": workerID,
	}

	var response struct {
		Data struct {
			WorkerPoolWorkerDrain struct {
				ID      string `json:"id"`
				Drained bool   `json:"drained"`
			} `json:"workerPoolWorkerDrain"`
		} `json:"data"`
	}

	return c.doGraphQLRequest(ctx, mutation, variables, &response)
}

// IsIdle returns true if the worker is idle (not busy and not drained)
func (w *Worker) IsIdle() bool {
	return !w.Busy && !w.Drained
}

func (c *Client) doGraphQLRequest(ctx context.Context, query string, variables map[string]interface{}, result interface{}) error {
	requestBody := map[string]interface{}{
		"query":     query,
		"variables": variables,
	}

	bodyBytes, err := json.Marshal(requestBody)
	if err != nil {
		return fmt.Errorf("failed to marshal request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", c.endpoint+"/graphql", bytes.NewReader(bodyBytes))
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", fmt.Sprintf("Bearer %s:%s", c.keyID, c.keySecret))

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("failed to execute request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("request failed with status %d: %s", resp.StatusCode, string(body))
	}

	if err := json.NewDecoder(resp.Body).Decode(result); err != nil {
		return fmt.Errorf("failed to decode response: %w", err)
	}

	return nil
}
