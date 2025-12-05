// Package router provides routing rule evaluation logic
package router

import (
	"regexp"
	"sort"
	"strings"
)

// Router evaluates routing rules against request attributes
type Router struct {
	config PluginConfig
}

// NewRouter creates a new router with the given configuration
func NewRouter(config PluginConfig) *Router {
	// Sort rules by priority
	rules := make([]RoutingRule, len(config.Rules))
	copy(rules, config.Rules)
	sort.Slice(rules, func(i, j int) bool {
		return rules[i].Priority < rules[j].Priority
	})
	config.Rules = rules

	return &Router{config: config}
}

// Evaluate evaluates all rules against the given headers and returns a routing decision
func (r *Router) Evaluate(headers map[string]string) RoutingDecision {
	// Try each rule in priority order
	for _, rule := range r.config.Rules {
		if r.evaluateRule(rule, headers) {
			return RoutingDecision{
				Target:        rule.Target,
				MatchedRule:   rule.Name,
				AddHeaders:    rule.AddHeaders,
				RemoveHeaders: rule.RemoveHeaders,
			}
		}
	}

	// No rule matched, return default
	return RoutingDecision{
		Target:      r.config.DefaultTarget,
		MatchedRule: "",
		AddHeaders: map[string]string{
			"X-Routed-By":    "smart-router",
			"X-Route-Reason": "default",
		},
		RemoveHeaders: nil,
	}
}

// evaluateRule checks if all conditions in a rule match
func (r *Router) evaluateRule(rule RoutingRule, headers map[string]string) bool {
	// All conditions must match (AND logic)
	for _, condition := range rule.Conditions {
		if !r.evaluateCondition(condition, headers) {
			return false
		}
	}
	return len(rule.Conditions) > 0 // Empty conditions never match
}

// evaluateCondition evaluates a single condition
func (r *Router) evaluateCondition(cond Condition, headers map[string]string) bool {
	var value string
	var exists bool

	switch cond.Type {
	case "header":
		value, exists = r.getHeader(headers, cond.Key)
	case "cookie":
		value, exists = r.getCookie(headers, cond.Key)
	case "path":
		value, exists = headers[":path"], headers[":path"] != ""
	case "query":
		value, exists = r.getQueryParam(headers, cond.Key)
	default:
		return false
	}

	return r.matchValue(cond.Operator, value, cond.Value, exists)
}

// getHeader gets a header value (case-insensitive)
func (r *Router) getHeader(headers map[string]string, key string) (string, bool) {
	// Try exact match first
	if v, ok := headers[key]; ok {
		return v, true
	}
	// Try case-insensitive match
	keyLower := strings.ToLower(key)
	for k, v := range headers {
		if strings.ToLower(k) == keyLower {
			return v, true
		}
	}
	return "", false
}

// getCookie extracts a cookie value from the Cookie header
func (r *Router) getCookie(headers map[string]string, name string) (string, bool) {
	cookieHeader, ok := headers["cookie"]
	if !ok {
		cookieHeader, ok = headers["Cookie"]
	}
	if !ok {
		return "", false
	}

	return ParseCookieValue(cookieHeader, name)
}

// getQueryParam extracts a query parameter from the path
func (r *Router) getQueryParam(headers map[string]string, key string) (string, bool) {
	path := headers[":path"]
	if path == "" {
		return "", false
	}

	// Find query string
	idx := strings.Index(path, "?")
	if idx == -1 {
		return "", false
	}

	query := path[idx+1:]
	pairs := strings.Split(query, "&")

	for _, pair := range pairs {
		parts := strings.SplitN(pair, "=", 2)
		if len(parts) == 2 && parts[0] == key {
			return parts[1], true
		}
		if len(parts) == 1 && parts[0] == key {
			return "", true
		}
	}

	return "", false
}

// matchValue checks if a value matches using the specified operator
func (r *Router) matchValue(operator, value, pattern string, exists bool) bool {
	switch operator {
	case "exists":
		return exists
	case "equals":
		return value == pattern
	case "contains":
		return strings.Contains(value, pattern)
	case "prefix":
		return strings.HasPrefix(value, pattern)
	case "suffix":
		return strings.HasSuffix(value, pattern)
	case "regex":
		re, err := regexp.Compile(pattern)
		if err != nil {
			return false
		}
		return re.MatchString(value)
	default:
		return false
	}
}

// DetermineRoute is a convenience function for simple routing decisions
func DetermineRoute(headers map[string]string) string {
	// Check for beta user criteria:
	// 1. User-Agent contains "iPhone"
	// 2. X-Geo-Country equals "DE"
	// 3. Cookie beta-tester=true

	userAgent, _ := headers["User-Agent"]
	if userAgent == "" {
		userAgent, _ = headers["user-agent"]
	}

	geoCountry, _ := headers["X-Geo-Country"]
	if geoCountry == "" {
		geoCountry, _ = headers["x-geo-country"]
	}

	cookieHeader, _ := headers["Cookie"]
	if cookieHeader == "" {
		cookieHeader, _ = headers["cookie"]
	}

	betaTester, _ := ParseCookieValue(cookieHeader, "beta-tester")

	// All three conditions must match for v2
	if strings.Contains(userAgent, "iPhone") &&
		geoCountry == "DE" &&
		betaTester == "true" {
		return "v2"
	}

	// Check for canary (hash-based)
	requestHash, _ := headers["X-Request-Hash"]
	if requestHash == "" {
		requestHash, _ = headers["x-request-hash"]
	}

	// Route 10% of traffic (hash digits 0-9)
	if len(requestHash) == 1 && requestHash >= "0" && requestHash <= "9" {
		return "v2"
	}

	return "v1"
}