// Smart Router - A/B Testing and Canary Deployment Wasm Plugin
//
// This proxy-wasm plugin inspects HTTP request headers and cookies
// to make routing decisions for A/B testing and canary deployments.
//
// Extension Point:
// - Location: Request Path
// - Callback: OnHttpRequestHeaders
package main

import (
	"encoding/json"

	"github.com/cloudrun-wasm-demos/smart-router/router"
	"github.com/tetratelabs/proxy-wasm-go-sdk/proxywasm"
	"github.com/tetratelabs/proxy-wasm-go-sdk/proxywasm/types"
)

// main is the entry point for the Wasm plugin
func main() {
	proxywasm.SetVMContext(&vmContext{})
}

// =============================================================================
// VM Context
// =============================================================================

// vmContext is the VM-level context
type vmContext struct {
	types.DefaultVMContext
}

// NewPluginContext creates a new plugin context for each plugin instance
func (*vmContext) NewPluginContext(contextID uint32) types.PluginContext {
	return &pluginContext{
		contextID: contextID,
		config:    router.DefaultConfig(),
	}
}

// =============================================================================
// Plugin Context
// =============================================================================

// pluginContext handles plugin-level initialization and configuration
type pluginContext struct {
	types.DefaultPluginContext
	contextID uint32
	config    router.PluginConfig
	router    *router.Router
}

// OnPluginStart is called when the plugin starts
func (ctx *pluginContext) OnPluginStart(pluginConfigurationSize int) types.OnPluginStartStatus {
	proxywasm.LogInfo("Smart Router plugin starting...")

	// Load configuration if provided
	if pluginConfigurationSize > 0 {
		configData, err := proxywasm.GetPluginConfiguration()
		if err != nil {
			proxywasm.LogWarnf("Failed to get plugin configuration: %v", err)
		} else {
			if err := json.Unmarshal(configData, &ctx.config); err != nil {
				proxywasm.LogWarnf("Failed to parse configuration: %v, using defaults", err)
				ctx.config = router.DefaultConfig()
			} else {
				proxywasm.LogInfof("Loaded configuration with %d rules", len(ctx.config.Rules))
			}
		}
	}

	// Create router with configuration
	ctx.router = router.NewRouter(ctx.config)

	proxywasm.LogInfof("Smart Router initialized. Default target: %s, Rules: %d",
		ctx.config.DefaultTarget, len(ctx.config.Rules))

	return types.OnPluginStartStatusOK
}

// NewHttpContext creates a new HTTP context for each request
func (ctx *pluginContext) NewHttpContext(contextID uint32) types.HttpContext {
	return &httpContext{
		contextID:    contextID,
		pluginConfig: ctx.config,
		router:       ctx.router,
	}
}

// =============================================================================
// HTTP Context
// =============================================================================

// httpContext handles individual HTTP requests
type httpContext struct {
	types.DefaultHttpContext
	contextID    uint32
	pluginConfig router.PluginConfig
	router       *router.Router
}

// OnHttpRequestHeaders is called when request headers are received
func (ctx *httpContext) OnHttpRequestHeaders(numHeaders int, endOfStream bool) types.Action {
	proxywasm.LogDebugf("[%d] Processing request headers (%d headers)", ctx.contextID, numHeaders)

	// Get all headers
	headers, err := proxywasm.GetHttpRequestHeaders()
	if err != nil {
		proxywasm.LogErrorf("[%d] Failed to get request headers: %v", ctx.contextID, err)
		return types.ActionContinue
	}

	// Convert to map for easier access
	headerMap := make(map[string]string)
	for _, h := range headers {
		headerMap[h[0]] = h[1]
	}

	// Log key headers for debugging
	if userAgent, ok := headerMap["user-agent"]; ok {
		proxywasm.LogDebugf("[%d] User-Agent: %s", ctx.contextID, userAgent)
	}
	if cookie, ok := headerMap["cookie"]; ok {
		proxywasm.LogDebugf("[%d] Cookie: %s", ctx.contextID, cookie)
	}

	// Make routing decision
	decision := ctx.router.Evaluate(headerMap)

	proxywasm.LogInfof("[%d] Routing decision: target=%s, rule=%s",
		ctx.contextID, decision.Target, decision.MatchedRule)

	// Set routing header for Envoy
	if err := proxywasm.ReplaceHttpRequestHeader("x-route-target", decision.Target); err != nil {
		proxywasm.LogWarnf("[%d] Failed to set x-route-target header: %v", ctx.contextID, err)
	}

	// Add attribution headers
	if decision.AddHeaders != nil {
		for key, value := range decision.AddHeaders {
			if err := proxywasm.AddHttpRequestHeader(key, value); err != nil {
				proxywasm.LogWarnf("[%d] Failed to add header %s: %v", ctx.contextID, key, err)
			}
		}
	}

	// Add standard routing headers
	if err := proxywasm.AddHttpRequestHeader("X-Routed-By", "smart-router"); err != nil {
		proxywasm.LogWarnf("[%d] Failed to add X-Routed-By header: %v", ctx.contextID, err)
	}

	routeReason := decision.MatchedRule
	if routeReason == "" {
		routeReason = "default"
	}
	if err := proxywasm.AddHttpRequestHeader("X-Route-Reason", routeReason); err != nil {
		proxywasm.LogWarnf("[%d] Failed to add X-Route-Reason header: %v", ctx.contextID, err)
	}

	// Remove headers if specified
	if decision.RemoveHeaders != nil {
		for _, key := range decision.RemoveHeaders {
			if err := proxywasm.RemoveHttpRequestHeader(key); err != nil {
				proxywasm.LogWarnf("[%d] Failed to remove header %s: %v", ctx.contextID, key, err)
			}
		}
	}

	return types.ActionContinue
}

// OnHttpResponseHeaders adds routing information to response headers
func (ctx *httpContext) OnHttpResponseHeaders(numHeaders int, endOfStream bool) types.Action {
	// Add backend version header if available from upstream
	if err := proxywasm.AddHttpResponseHeader("X-Smart-Router", "active"); err != nil {
		proxywasm.LogWarnf("[%d] Failed to add X-Smart-Router header: %v", ctx.contextID, err)
	}

	return types.ActionContinue
}