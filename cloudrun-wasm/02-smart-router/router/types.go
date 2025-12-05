// Package router provides routing rule definitions and evaluation logic
// for the Smart Router proxy-wasm plugin.
package router

// RoutingRule defines a condition and target for routing
type RoutingRule struct {
	// Name is a human-readable identifier
	Name string `json:"name"`

	// Priority determines evaluation order (lower = first)
	Priority int `json:"priority"`

	// Conditions that must ALL match (AND logic)
	Conditions []Condition `json:"conditions"`

	// Target backend to route to if conditions match
	Target string `json:"target"`

	// AddHeaders to add to the request
	AddHeaders map[string]string `json:"add_headers,omitempty"`

	// RemoveHeaders to remove from the request
	RemoveHeaders []string `json:"remove_headers,omitempty"`
}

// Condition defines a single matching rule
type Condition struct {
	// Type of condition: "header", "cookie", "path", "query"
	Type string `json:"type"`

	// Key to check (header name, cookie name, etc.)
	Key string `json:"key"`

	// Operator: "equals", "contains", "regex", "exists", "prefix", "suffix"
	Operator string `json:"operator"`

	// Value to match against (ignored for "exists" operator)
	Value string `json:"value,omitempty"`
}

// RoutingDecision is the result of evaluating rules
type RoutingDecision struct {
	// Target backend (e.g., "v1" or "v2")
	Target string

	// MatchedRule is the name of the rule that matched (empty if default)
	MatchedRule string

	// AddHeaders to add to the request
	AddHeaders map[string]string

	// RemoveHeaders to remove from the request
	RemoveHeaders []string
}

// PluginConfig is the configuration for the router plugin
type PluginConfig struct {
	// LogLevel for the plugin
	LogLevel string `json:"log_level"`

	// DefaultTarget when no rules match
	DefaultTarget string `json:"default_target"`

	// Rules to evaluate
	Rules []RoutingRule `json:"rules"`
}

// DefaultConfig returns the default plugin configuration
func DefaultConfig() PluginConfig {
	return PluginConfig{
		LogLevel:      "info",
		DefaultTarget: "v1",
		Rules:         []RoutingRule{},
	}
}