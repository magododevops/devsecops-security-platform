package maintenance

import "context"

type WorkOrder struct {
	ID       string `json:"id"`
	TenantID string `json:"tenant_id"`
	AssetID  string `json:"asset_id"`
	Title    string `json:"title"`
	Status   string `json:"status"`
}

type Identity struct {
	UserID   string
	TenantID string
	Role     string
}

type Service struct {
	orders map[string]WorkOrder
}

func NewService() *Service {
	return &Service{
		orders: map[string]WorkOrder{
			"WO-1001": {
				ID:       "WO-1001",
				TenantID: "tenant-alpha",
				AssetID:  "A-100",
				Title:    "Inspect hydraulic pump",
				Status:   "open",
			},
			"WO-2001": {
				ID:       "WO-2001",
				TenantID: "tenant-beta",
				AssetID:  "B-200",
				Title:    "Inspect industrial turbine",
				Status:   "open",
			},
		},
	}
}

func (s *Service) GetWorkOrder(
	_ context.Context,
	identity Identity,
	id string,
) (WorkOrder, bool) {
	order, exists := s.orders[id]

	if !exists || order.TenantID != identity.TenantID {
		return WorkOrder{}, false
	}

	return order, true
}

// GetWorkOrderWithoutTenantCheck intentionally omits tenant authorization.
// LAB ONLY: Never use this method in production code paths.
func (s *Service) GetWorkOrderWithoutTenantCheck(
	_ context.Context,
	id string,
) (WorkOrder, bool) {
	order, exists := s.orders[id]
	return order, exists
}
