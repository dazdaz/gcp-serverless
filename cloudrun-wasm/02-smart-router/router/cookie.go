// Package router provides cookie parsing utilities
package router

import (
	"net/url"
	"strings"
)

// ParseCookieValue extracts a specific cookie value from a Cookie header string.
// The Cookie header format is: "name1=value1; name2=value2; ..."
// Handles URL-encoded values.
func ParseCookieValue(cookieHeader, name string) (string, bool) {
	if cookieHeader == "" {
		return "", false
	}

	// Split by semicolon
	pairs := strings.Split(cookieHeader, ";")

	for _, pair := range pairs {
		// Trim whitespace
		pair = strings.TrimSpace(pair)

		// Split by equals
		parts := strings.SplitN(pair, "=", 2)
		if len(parts) != 2 {
			continue
		}

		cookieName := strings.TrimSpace(parts[0])
		cookieValue := strings.TrimSpace(parts[1])

		if cookieName == name {
			// Try to URL-decode the value
			decoded, err := url.QueryUnescape(cookieValue)
			if err != nil {
				// If decoding fails, return the original value
				return cookieValue, true
			}
			return decoded, true
		}
	}

	return "", false
}

// ParseAllCookies parses all cookies from a Cookie header string
// Returns a map of cookie name -> value
func ParseAllCookies(cookieHeader string) map[string]string {
	cookies := make(map[string]string)

	if cookieHeader == "" {
		return cookies
	}

	pairs := strings.Split(cookieHeader, ";")

	for _, pair := range pairs {
		pair = strings.TrimSpace(pair)
		parts := strings.SplitN(pair, "=", 2)

		if len(parts) != 2 {
			continue
		}

		name := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])

		// Try to URL-decode
		decoded, err := url.QueryUnescape(value)
		if err != nil {
			cookies[name] = value
		} else {
			cookies[name] = decoded
		}
	}

	return cookies
}

// HasCookie checks if a specific cookie exists in the Cookie header
func HasCookie(cookieHeader, name string) bool {
	_, exists := ParseCookieValue(cookieHeader, name)
	return exists
}