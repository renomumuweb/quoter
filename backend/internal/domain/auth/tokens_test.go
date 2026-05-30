package auth

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestAccessTokenRoundTrip(t *testing.T) {
	manager := NewTokenManager("test-secret-with-enough-length", time.Minute, time.Hour)
	user := User{
		ID:        uuid.New(),
		CompanyID: uuid.New(),
		Email:     "owner@example.com",
		Role:      "admin",
	}

	raw, _, err := manager.SignAccessToken(user)
	if err != nil {
		t.Fatalf("sign token: %v", err)
	}
	claims, err := manager.ParseAccessToken(raw)
	if err != nil {
		t.Fatalf("parse token: %v", err)
	}
	if claims.UserID != user.ID.String() || claims.CompanyID != user.CompanyID.String() {
		t.Fatalf("claims mismatch: %#v", claims)
	}
}

func TestRefreshTokenHashDoesNotExposeToken(t *testing.T) {
	token, err := GenerateRefreshToken()
	if err != nil {
		t.Fatalf("generate refresh: %v", err)
	}
	hash := HashRefreshToken(token)
	if hash == token {
		t.Fatal("hash should not equal raw refresh token")
	}
	if len(hash) != 64 {
		t.Fatalf("expected sha256 hex length 64, got %d", len(hash))
	}
}
