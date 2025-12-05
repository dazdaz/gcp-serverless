package router

import (
	"testing"
)

func TestParseCookieValue_Simple(t *testing.T) {
	cookieHeader := "session=abc123"
	value, exists := ParseCookieValue(cookieHeader, "session")

	if !exists {
		t.Error("Expected cookie to exist")
	}
	if value != "abc123" {
		t.Errorf("Expected 'abc123', got '%s'", value)
	}
}

func TestParseCookieValue_Multiple(t *testing.T) {
	cookieHeader := "session=abc123; beta-tester=true; user_id=42"

	tests := []struct {
		name     string
		expected string
		exists   bool
	}{
		{"session", "abc123", true},
		{"beta-tester", "true", true},
		{"user_id", "42", true},
		{"nonexistent", "", false},
	}

	for _, tt := range tests {
		value, exists := ParseCookieValue(cookieHeader, tt.name)
		if exists != tt.exists {
			t.Errorf("Cookie '%s': expected exists=%v, got exists=%v", tt.name, tt.exists, exists)
		}
		if value != tt.expected {
			t.Errorf("Cookie '%s': expected '%s', got '%s'", tt.name, tt.expected, value)
		}
	}
}

func TestParseCookieValue_URLEncoded(t *testing.T) {
	cookieHeader := "data=hello%20world; encoded=%3D%3D"

	tests := []struct {
		name     string
		expected string
	}{
		{"data", "hello world"},
		{"encoded", "=="},
	}

	for _, tt := range tests {
		value, _ := ParseCookieValue(cookieHeader, tt.name)
		if value != tt.expected {
			t.Errorf("Cookie '%s': expected '%s', got '%s'", tt.name, tt.expected, value)
		}
	}
}

func TestParseCookieValue_Whitespace(t *testing.T) {
	cookieHeader := "  session = abc123 ;  beta = true  "

	value, exists := ParseCookieValue(cookieHeader, "session")
	if !exists {
		t.Error("Expected cookie to exist")
	}
	if value != "abc123" {
		t.Errorf("Expected 'abc123', got '%s'", value)
	}

	value, exists = ParseCookieValue(cookieHeader, "beta")
	if !exists {
		t.Error("Expected beta cookie to exist")
	}
	if value != "true" {
		t.Errorf("Expected 'true', got '%s'", value)
	}
}

func TestParseCookieValue_Empty(t *testing.T) {
	_, exists := ParseCookieValue("", "session")
	if exists {
		t.Error("Expected cookie not to exist in empty header")
	}
}

func TestParseCookieValue_MalformedCookies(t *testing.T) {
	// Cookie without value
	cookieHeader := "session; beta=true"

	value, exists := ParseCookieValue(cookieHeader, "beta")
	if !exists {
		t.Error("Expected beta cookie to exist")
	}
	if value != "true" {
		t.Errorf("Expected 'true', got '%s'", value)
	}

	// The malformed "session" cookie should not be found as it has no value
	_, exists = ParseCookieValue(cookieHeader, "session")
	if exists {
		t.Error("Expected malformed cookie without value to not be found")
	}
}

func TestParseAllCookies(t *testing.T) {
	cookieHeader := "session=abc123; beta-tester=true; user_id=42"

	cookies := ParseAllCookies(cookieHeader)

	expected := map[string]string{
		"session":     "abc123",
		"beta-tester": "true",
		"user_id":     "42",
	}

	for name, expectedValue := range expected {
		if cookies[name] != expectedValue {
			t.Errorf("Cookie '%s': expected '%s', got '%s'", name, expectedValue, cookies[name])
		}
	}
}

func TestParseAllCookies_Empty(t *testing.T) {
	cookies := ParseAllCookies("")

	if len(cookies) != 0 {
		t.Errorf("Expected empty map, got %d cookies", len(cookies))
	}
}

func TestHasCookie(t *testing.T) {
	cookieHeader := "session=abc123; beta-tester=true"

	if !HasCookie(cookieHeader, "session") {
		t.Error("Expected session cookie to exist")
	}

	if !HasCookie(cookieHeader, "beta-tester") {
		t.Error("Expected beta-tester cookie to exist")
	}

	if HasCookie(cookieHeader, "nonexistent") {
		t.Error("Expected nonexistent cookie to not exist")
	}
}