package main

import (
	"context"
	"log/slog"
	"os"
	"os/signal"
	"syscall"
	"time"

	"quoter/backend/internal/config"
	authdomain "quoter/backend/internal/domain/auth"
	"quoter/backend/internal/httpserver"
	"quoter/backend/internal/platform/database"
	"quoter/backend/internal/platform/migrations"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))

	cfg, err := config.Load()
	if err != nil {
		logger.Error("load config", "error", err)
		os.Exit(1)
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	pool, err := database.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		logger.Error("connect database", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	if cfg.RunMigrations {
		runner := migrations.NewRunner(pool, cfg.MigrationsDir)
		if err := runner.Up(ctx); err != nil {
			logger.Error("run migrations", "error", err)
			os.Exit(1)
		}
		logger.Info("migrations completed")
	}

	tokenManager := authdomain.NewTokenManager(cfg.JWTSecret, cfg.AccessTokenTTL, cfg.RefreshTokenTTL)
	authService := authdomain.NewService(pool, tokenManager, cfg.BcryptCost)
	server := httpserver.New(httpserver.Dependencies{
		Config:       cfg,
		DB:           pool,
		Logger:       logger,
		AuthService:  authService,
		TokenManager: tokenManager,
	})

	go func() {
		logger.Info("quoter api listening", "addr", cfg.APIAddr)
		if err := server.ListenAndServe(); err != nil {
			logger.Error("server stopped", "error", err)
			stop()
		}
	}()

	<-ctx.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := server.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown server", "error", err)
	}
}
