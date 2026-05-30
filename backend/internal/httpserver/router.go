package httpserver

import (
	"context"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"

	"quoter/backend/internal/config"
	authdomain "quoter/backend/internal/domain/auth"
	"quoter/backend/internal/httpserver/handlers"
	"quoter/backend/internal/httpserver/middleware"
)

type Dependencies struct {
	Config       config.Config
	DB           *pgxpool.Pool
	Logger       *slog.Logger
	AuthService  *authdomain.Service
	TokenManager authdomain.TokenManager
}

type Server struct {
	httpServer *http.Server
}

func New(deps Dependencies) *Server {
	if deps.Config.AppEnv == "production" {
		gin.SetMode(gin.ReleaseMode)
	}

	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(requestLogger(deps.Logger))
	router.Use(cors(deps.Config.AllowedOrigins))

	health := handlers.NewHealthHandler(deps.DB)
	router.GET("/healthz", health.Health)
	router.GET("/readyz", health.Ready)

	authHandler := handlers.NewAuthHandler(deps.AuthService)
	api := router.Group("/api/v1")
	api.GET("/healthz", health.Health)
	api.POST("/auth/register", authHandler.Register)
	api.POST("/auth/login", authHandler.Login)
	api.POST("/auth/refresh", authHandler.Refresh)

	protected := api.Group("")
	protected.Use(middleware.Auth(deps.TokenManager))
	protected.POST("/auth/logout", authHandler.Logout)
	protected.GET("/auth/me", authHandler.Me)

	registerScaffoldRoutes(protected)

	return &Server{
		httpServer: &http.Server{
			Addr:              deps.Config.APIAddr,
			Handler:           router,
			ReadHeaderTimeout: 5 * time.Second,
		},
	}
}

func (s *Server) ListenAndServe() error {
	err := s.httpServer.ListenAndServe()
	if err == http.ErrServerClosed {
		return nil
	}
	return err
}

func (s *Server) Shutdown(ctx context.Context) error {
	return s.httpServer.Shutdown(ctx)
}

func registerScaffoldRoutes(router *gin.RouterGroup) {
	notReady := handlers.NotImplemented

	router.GET("/customers", notReady("customers.list", "Phase 5"))
	router.POST("/customers", notReady("customers.create", "Phase 5"))
	router.GET("/customers/:id", notReady("customers.get", "Phase 5"))
	router.PUT("/customers/:id", notReady("customers.update", "Phase 5"))
	router.DELETE("/customers/:id", notReady("customers.delete", "Phase 5"))

	router.GET("/projects", notReady("projects.list", "Phase 5"))
	router.POST("/projects", notReady("projects.create", "Phase 5"))
	router.GET("/projects/:id", notReady("projects.get", "Phase 5"))
	router.PUT("/projects/:id", notReady("projects.update", "Phase 5"))
	router.DELETE("/projects/:id", notReady("projects.delete", "Phase 5"))

	router.GET("/projects/:id/drawing", notReady("drawing.get", "Phase 6"))
	router.PUT("/projects/:id/drawing", notReady("drawing.save", "Phase 6"))
	router.POST("/projects/:id/drawing/upload-url", notReady("drawing.upload_url", "Phase 6"))
	router.POST("/drawing-objects", notReady("drawing_objects.create", "Phase 6"))
	router.PUT("/drawing-objects/:id", notReady("drawing_objects.update", "Phase 6"))
	router.DELETE("/drawing-objects/:id", notReady("drawing_objects.delete", "Phase 6"))
	router.POST("/drawing-annotations", notReady("drawing_annotations.create", "Phase 6"))
	router.PUT("/drawing-annotations/:id", notReady("drawing_annotations.update", "Phase 6"))
	router.DELETE("/drawing-annotations/:id", notReady("drawing_annotations.delete", "Phase 6"))

	router.GET("/products", notReady("products.list", "Phase 7"))
	router.GET("/products/recommendations", notReady("products.recommendations", "Phase 7"))
	router.GET("/products/:id", notReady("products.get", "Phase 7"))
	router.GET("/product-categories", notReady("product_categories.list", "Phase 7"))
	router.GET("/brands", notReady("brands.list", "Phase 7"))

	router.POST("/projects/:id/quotes/preview", notReady("quotes.preview", "Phase 8"))
	router.POST("/projects/:id/quotes", notReady("quotes.create", "Phase 8"))
	router.GET("/quotes/:id", notReady("quotes.get", "Phase 8"))
	router.POST("/quotes/:id/confirm", notReady("quotes.confirm", "Phase 8"))

	router.POST("/quotes/:id/contracts", notReady("contracts.create", "Phase 9"))
	router.GET("/contracts/:id", notReady("contracts.get", "Phase 9"))
	router.POST("/contracts/:id/pdf", notReady("contracts.pdf", "Phase 9"))
	router.GET("/contracts/:id/download-url", notReady("contracts.download_url", "Phase 9"))
}

func requestLogger(logger *slog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		logger.Info("request",
			"method", c.Request.Method,
			"path", c.FullPath(),
			"status", c.Writer.Status(),
			"latency_ms", time.Since(start).Milliseconds(),
		)
	}
}

func cors(allowed []string) gin.HandlerFunc {
	allowAll := false
	allowedSet := map[string]struct{}{}
	for _, origin := range allowed {
		if origin == "*" {
			allowAll = true
			continue
		}
		allowedSet[strings.TrimSpace(origin)] = struct{}{}
	}

	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if origin != "" {
			if _, ok := allowedSet[origin]; ok || allowAll {
				c.Header("Access-Control-Allow-Origin", origin)
				c.Header("Vary", "Origin")
				c.Header("Access-Control-Allow-Credentials", "true")
				c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type")
				c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
			}
		}
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}
