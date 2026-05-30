package config

import (
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	AppEnv          string
	APIAddr         string
	DatabaseURL     string
	JWTSecret       string
	AccessTokenTTL  time.Duration
	RefreshTokenTTL time.Duration
	BcryptCost      int
	RunMigrations   bool
	MigrationsDir   string
	AllowedOrigins  []string
}

func Load() (Config, error) {
	cfg := Config{
		AppEnv:          getenv("APP_ENV", "development"),
		APIAddr:         getenv("API_ADDR", ":8080"),
		DatabaseURL:     os.Getenv("DATABASE_URL"),
		JWTSecret:       os.Getenv("JWT_SECRET"),
		AccessTokenTTL:  minutes("ACCESS_TOKEN_TTL_MINUTES", 15),
		RefreshTokenTTL: hours("REFRESH_TOKEN_TTL_HOURS", 720),
		BcryptCost:      intValue("BCRYPT_COST", 12),
		RunMigrations:   boolValue("RUN_MIGRATIONS", false),
		MigrationsDir:   getenv("MIGRATIONS_DIR", "migrations"),
		AllowedOrigins:  csv("CORS_ALLOWED_ORIGINS", []string{"http://localhost:3000"}),
	}

	if cfg.DatabaseURL == "" {
		return Config{}, errors.New("DATABASE_URL is required")
	}
	if cfg.JWTSecret == "" {
		if cfg.AppEnv == "production" {
			return Config{}, errors.New("JWT_SECRET is required in production")
		}
		cfg.JWTSecret = "dev-only-change-me"
	}
	if len(cfg.JWTSecret) < 24 {
		return Config{}, fmt.Errorf("JWT_SECRET must be at least 24 characters")
	}
	if cfg.BcryptCost < 10 {
		return Config{}, fmt.Errorf("BCRYPT_COST must be >= 10")
	}

	return cfg, nil
}

func getenv(key, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(key)); value != "" {
		return value
	}
	return fallback
}

func intValue(key string, fallback int) int {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func boolValue(key string, fallback bool) bool {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	parsed, err := strconv.ParseBool(value)
	if err != nil {
		return fallback
	}
	return parsed
}

func minutes(key string, fallback int) time.Duration {
	return time.Duration(intValue(key, fallback)) * time.Minute
}

func hours(key string, fallback int) time.Duration {
	return time.Duration(intValue(key, fallback)) * time.Hour
}

func csv(key string, fallback []string) []string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	parts := strings.Split(value, ",")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		part = strings.TrimSpace(part)
		if part != "" {
			out = append(out, part)
		}
	}
	if len(out) == 0 {
		return fallback
	}
	return out
}
