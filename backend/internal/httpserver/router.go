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

	businessHandler := handlers.NewBusinessHandler(deps.DB)
	registerBusinessRoutes(protected, businessHandler)

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

func registerBusinessRoutes(router *gin.RouterGroup, handler handlers.BusinessHandler) {
	router.GET("/customers", handler.ListCustomers)
	router.POST("/customers", handler.CreateCustomer)
	router.GET("/customers/:id", handler.GetCustomer)
	router.PUT("/customers/:id", handler.UpdateCustomer)
	router.DELETE("/customers/:id", handler.DeleteCustomer)

	router.GET("/projects", handler.ListProjects)
	router.POST("/projects", handler.CreateProject)
	router.GET("/projects/:id", handler.GetProject)
	router.PUT("/projects/:id", handler.UpdateProject)
	router.DELETE("/projects/:id", handler.DeleteProject)

	router.GET("/projects/:id/drawing", handler.GetDrawing)
	router.PUT("/projects/:id/drawing", handler.UpdateDrawing)
	router.POST("/projects/:id/drawing/upload-url", handler.CreateDrawingUploadURL)
	router.PUT("/file-assets/:id/upload", handler.UploadFileAsset)
	router.GET("/file-assets/:id/download", handler.DownloadFileAsset)
	router.POST("/drawing-objects", handler.CreateDrawingObject)
	router.PUT("/drawing-objects/:id", handler.UpdateDrawingObject)
	router.DELETE("/drawing-objects/:id", handler.DeleteDrawingObject)
	router.POST("/drawing-annotations", handler.CreateDrawingAnnotation)
	router.PUT("/drawing-annotations/:id", handler.UpdateDrawingAnnotation)
	router.DELETE("/drawing-annotations/:id", handler.DeleteDrawingAnnotation)

	router.GET("/products", handler.ListProducts)
	router.POST("/products", handler.CreateProduct)
	router.GET("/products/recommendations", handler.RecommendProducts)
	router.GET("/products/:id", handler.GetProduct)
	router.PUT("/products/:id", handler.UpdateProduct)
	router.DELETE("/products/:id", handler.DeleteProduct)
	router.GET("/product-categories", handler.ListProductCategories)
	router.POST("/product-categories", handler.CreateProductCategory)
	router.PUT("/product-categories/:id", handler.UpdateProductCategory)
	router.DELETE("/product-categories/:id", handler.DeleteProductCategory)
	router.GET("/brands", handler.ListBrands)
	router.POST("/brands", handler.CreateBrand)
	router.PUT("/brands/:id", handler.UpdateBrand)
	router.DELETE("/brands/:id", handler.DeleteBrand)

	router.POST("/projects/:id/quotes/preview", handler.PreviewQuote)
	router.POST("/projects/:id/quotes", handler.CreateQuote)
	router.GET("/quotes", handler.ListQuotes)
	router.GET("/quotes/:id", handler.GetQuote)
	router.POST("/quotes/:id/confirm", handler.ConfirmQuote)

	router.POST("/quotes/:id/contracts", handler.CreateContract)
	router.GET("/contracts", handler.ListContracts)
	router.GET("/contracts/:id", handler.GetContract)
	router.POST("/contracts/:id/pdf", handler.CreateContractPDFRecord)
	router.GET("/contracts/:id/download-url", handler.GetContractDownloadURL)
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
