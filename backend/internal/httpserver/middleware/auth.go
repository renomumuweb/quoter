package middleware

import (
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"

	authdomain "quoter/backend/internal/domain/auth"
)

const ClaimsKey = "auth.claims"

func Auth(tokens authdomain.TokenManager) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if header == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing authorization header"})
			return
		}
		parts := strings.SplitN(header, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header"})
			return
		}
		claims, err := tokens.ParseAccessToken(parts[1])
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
			return
		}
		c.Set(ClaimsKey, claims)
		c.Next()
	}
}

func Claims(c *gin.Context) (authdomain.Claims, bool) {
	value, ok := c.Get(ClaimsKey)
	if !ok {
		return authdomain.Claims{}, false
	}
	claims, ok := value.(authdomain.Claims)
	return claims, ok
}
