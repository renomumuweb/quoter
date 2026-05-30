package handlers

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"

	authdomain "quoter/backend/internal/domain/auth"
	"quoter/backend/internal/httpserver/middleware"
)

type AuthHandler struct {
	service *authdomain.Service
}

func NewAuthHandler(service *authdomain.Service) AuthHandler {
	return AuthHandler{service: service}
}

func (h AuthHandler) Register(c *gin.Context) {
	var input authdomain.RegisterInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid JSON body"})
		return
	}
	response, err := h.service.Register(c.Request.Context(), input, c.GetHeader("User-Agent"), c.ClientIP())
	writeAuthResponse(c, response, err)
}

func (h AuthHandler) Login(c *gin.Context) {
	var input authdomain.LoginInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid JSON body"})
		return
	}
	response, err := h.service.Login(c.Request.Context(), input, c.GetHeader("User-Agent"), c.ClientIP())
	writeAuthResponse(c, response, err)
}

func (h AuthHandler) Refresh(c *gin.Context) {
	var input authdomain.RefreshInput
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid JSON body"})
		return
	}
	response, err := h.service.Refresh(c.Request.Context(), input, c.GetHeader("User-Agent"), c.ClientIP())
	writeAuthResponse(c, response, err)
}

func (h AuthHandler) Logout(c *gin.Context) {
	claims, ok := middleware.Claims(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing claims"})
		return
	}
	var input authdomain.LogoutInput
	_ = c.ShouldBindJSON(&input)
	if err := h.service.Logout(c.Request.Context(), input, claims); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "logout failed"})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h AuthHandler) Me(c *gin.Context) {
	claims, ok := middleware.Claims(c)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing claims"})
		return
	}
	response, err := h.service.Me(c.Request.Context(), claims)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load user"})
		return
	}
	c.JSON(http.StatusOK, response)
}

func writeAuthResponse(c *gin.Context, response authdomain.AuthResponse, err error) {
	if err == nil {
		c.JSON(http.StatusOK, response)
		return
	}
	switch {
	case errors.Is(err, authdomain.ErrEmailTaken):
		c.JSON(http.StatusConflict, gin.H{"error": "email is already registered"})
	case errors.Is(err, authdomain.ErrInvalidCredentials):
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid email or password"})
	case errors.Is(err, authdomain.ErrInvalidRefresh):
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid refresh token"})
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
	}
}
