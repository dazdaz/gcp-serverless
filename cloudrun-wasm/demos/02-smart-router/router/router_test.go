package router

import (
	"testing"
)

func TestDetermineRoute_BetaTester(t *testing.T) {
	headers := map[string]string{
		"User-Agent":    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)",
		"X-Geo-Country": "DE",
		"Cookie":        "session=abc123; beta-tester=true",
	}

	result := DetermineRoute(headers)
	if result != "v2" {
		t.Errorf("Expected v2 for beta tester, got %s", result)
	}
}

func TestDetermineRoute_PartialMatch_IPhoneOnly(t *testing.T) {
	headers := map[string]string{
		"User-Agent":    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)",
		"X-Geo-Country": "US",
	}

	result := DetermineRoute(headers)
	if result != "v1" {
		t.Errorf("Expected v1 for partial match (iPhone only), got %s", result)
	}
}

func TestDetermineRoute_PartialMatch_NoBetaCookie(t *testing.T) {
	headers := map[string]string{
		"User-Agent":    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)",
		"X-Geo-Country": "DE",
		"Cookie":        "session=abc123",
	}

	result := DetermineRoute(headers)
	if result != "v1" {
		t.Errorf("Expected v1 for partial match (no beta cookie), got %s", result)
	}
}

func TestDetermineRoute_CanaryHash(t *testing.T) {
	// Hash value 0-9 should route to v2
	headers := map[string]string{
		"User-Agent":     "Chrome/120.0",
		"X-Request-Hash": "5",
	}

	result := DetermineRoute(headers)
	if result != "v2" {
		t.Errorf("Expected v2 for canary hash, got %s", result)
	}
}

func TestDetermineRoute_Default(t *testing.T) {
	headers := map[string]string{
		"User-Agent": "Chrome/120.0",
	}

	result := DetermineRoute(headers)
	if result != "v1" {
		t.Errorf("Expected v1 for default routing, got %s", result)
	}
}

func TestDetermineRoute_CaseInsensitive(t *testing.T) {
	headers := map[string]string{
		"user-agent":    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)",
		"x-geo-country": "DE",
		"cookie":        "beta-tester=true",
	}

	result := DetermineRoute(headers)
	if result != "v2" {
		t.Errorf("Expected v2 with lowercase headers, got %s", result)
	}
}

func TestRouter_Evaluate_BetaTesters(t *testing.T) {
	config := PluginConfig{
		DefaultTarget: "v1",
		Rules: []RoutingRule{
			{
				Name:     "beta-testers",
				Priority: 1,
				Conditions: []Condition{
					{Type: "header", Key: "User-Agent", Operator: "contains", Value: "iPhone"},
					{Type: "header", Key: "X-Geo-Country", Operator: "equals", Value: "DE"},
					{Type: "cookie", Key: "beta-tester", Operator: "equals", Value: "true"},
				},
				Target: "v2",
				AddHeaders: map[string]string{
					"X-Routed-By":    "smart-router",
					"X-Route-Reason": "beta-tester-match",
				},
			},
		},
	}

	r := NewRouter(config)

	headers := map[string]string{
		"User-Agent":    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0)",
		"X-Geo-Country": "DE",
		"Cookie":        "session=abc; beta-tester=true",
	}

	decision := r.Evaluate(headers)

	if decision.Target != "v2" {
		t.Errorf("Expected target v2, got %s", decision.Target)
	}
	if decision.MatchedRule != "beta-testers" {
		t.Errorf("Expected matched rule 'beta-testers', got '%s'", decision.MatchedRule)
	}
	if decision.AddHeaders["X-Route-Reason"] != "beta-tester-match" {
		t.Errorf("Expected X-Route-Reason 'beta-tester-match', got '%s'", decision.AddHeaders["X-Route-Reason"])
	}
}

func TestRouter_Evaluate_DefaultRoute(t *testing.T) {
	config := PluginConfig{
		DefaultTarget: "v1",
		Rules: []RoutingRule{
			{
				Name:     "beta-testers",
				Priority: 1,
				Conditions: []Condition{
					{Type: "header", Key: "User-Agent", Operator: "contains", Value: "iPhone"},
				},
				Target: "v2",
			},
		},
	}

	r := NewRouter(config)

	headers := map[string]string{
		"User-Agent": "Chrome/120.0",
	}

	decision := r.Evaluate(headers)

	if decision.Target != "v1" {
		t.Errorf("Expected target v1, got %s", decision.Target)
	}
	if decision.MatchedRule != "" {
		t.Errorf("Expected empty matched rule, got '%s'", decision.MatchedRule)
	}
}

func TestRouter_Evaluate_Priority(t *testing.T) {
	config := PluginConfig{
		DefaultTarget: "v1",
		Rules: []RoutingRule{
			{
				Name:     "low-priority",
				Priority: 10,
				Conditions: []Condition{
					{Type: "header", Key: "User-Agent", Operator: "contains", Value: "Chrome"},
				},
				Target: "v1-special",
			},
			{
				Name:     "high-priority",
				Priority: 1,
				Conditions: []Condition{
					{Type: "header", Key: "X-Priority", Operator: "equals", Value: "high"},
				},
				Target: "v2-priority",
			},
		},
	}

	r := NewRouter(config)

	headers := map[string]string{
		"User-Agent": "Chrome/120.0",
		"X-Priority": "high",
	}

	decision := r.Evaluate(headers)

	// High priority rule should match first
	if decision.Target != "v2-priority" {
		t.Errorf("Expected target v2-priority (high priority), got %s", decision.Target)
	}
	if decision.MatchedRule != "high-priority" {
		t.Errorf("Expected matched rule 'high-priority', got '%s'", decision.MatchedRule)
	}
}

func TestRouter_Evaluate_RegexOperator(t *testing.T) {
	config := PluginConfig{
		DefaultTarget: "v1",
		Rules: []RoutingRule{
			{
				Name:     "canary",
				Priority: 1,
				Conditions: []Condition{
					{Type: "header", Key: "X-Request-Hash", Operator: "regex", Value: "^[0-9]$"},
				},
				Target: "v2-canary",
			},
		},
	}

	r := NewRouter(config)

	tests := []struct {
		hash     string
		expected string
	}{
		{"5", "v2-canary"},
		{"0", "v2-canary"},
		{"9", "v2-canary"},
		{"a", "v1"},
		{"10", "v1"},
		{"", "v1"},
	}

	for _, tt := range tests {
		headers := map[string]string{
			"X-Request-Hash": tt.hash,
		}
		decision := r.Evaluate(headers)
		if decision.Target != tt.expected {
			t.Errorf("Hash '%s': expected %s, got %s", tt.hash, tt.expected, decision.Target)
		}
	}
}

func TestRouter_Evaluate_ExistsOperator(t *testing.T) {
	config := PluginConfig{
		DefaultTarget: "v1",
		Rules: []RoutingRule{
			{
				Name:     "has-header",
				Priority: 1,
				Conditions: []Condition{
					{Type: "header", Key: "X-Beta", Operator: "exists"},
				},
				Target: "v2",
			},
		},
	}

	r := NewRouter(config)

	// With header
	headers := map[string]string{
		"X-Beta": "anything",
	}
	decision := r.Evaluate(headers)
	if decision.Target != "v2" {
		t.Errorf("Expected v2 when header exists, got %s", decision.Target)
	}

	// Without header
	headers = map[string]string{}
	decision = r.Evaluate(headers)
	if decision.Target != "v1" {
		t.Errorf("Expected v1 when header missing, got %s", decision.Target)
	}
}

func TestRouter_Evaluate_PathCondition(t *testing.T) {
	config := PluginConfig{
		DefaultTarget: "v1",
		Rules: []RoutingRule{
			{
				Name:     "api-v2",
				Priority: 1,
				Conditions: []Condition{
					{Type: "path", Key: "", Operator: "prefix", Value: "/v2/"},
				},
				Target: "v2",
			},
		},
	}

	r := NewRouter(config)

	tests := []struct {
		path     string
		expected string
	}{
		{"/v2/api/test", "v2"},
		{"/v2/users", "v2"},
		{"/v1/api/test", "v1"},
		{"/api/test", "v1"},
	}

	for _, tt := range tests {
		headers := map[string]string{
			":path": tt.path,
		}
		decision := r.Evaluate(headers)
		if decision.Target != tt.expected {
			t.Errorf("Path '%s': expected %s, got %s", tt.path, tt.expected, decision.Target)
		}
	}
}

func TestRouter_Evaluate_QueryCondition(t *testing.T) {
	config := PluginConfig{
		DefaultTarget: "v1",
		Rules: []RoutingRule{
			{
				Name:     "beta-flag",
				Priority: 1,
				Conditions: []Condition{
					{Type: "query", Key: "beta", Operator: "equals", Value: "true"},
				},
				Target: "v2",
			},
		},
	}

	r := NewRouter(config)

	tests := []struct {
		path     string
		expected string
	}{
		{"/api/test?beta=true", "v2"},
		{"/api/test?beta=false", "v1"},
		{"/api/test", "v1"},
		{"/api/test?other=value", "v1"},
	}

	for _, tt := range tests {
		headers := map[string]string{
			":path": tt.path,
		}
		decision := r.Evaluate(headers)
		if decision.Target != tt.expected {
			t.Errorf("Path '%s': expected %s, got %s", tt.path, tt.expected, decision.Target)
		}
	}
}