FROM golang:1.24-alpine AS build

WORKDIR /src
ENV GOPROXY=https://goproxy.cn,direct
ENV GOSUMDB=sum.golang.org
RUN apk add --no-cache ca-certificates
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/quoter-api ./cmd/api

FROM alpine:3.22

RUN adduser -D -H appuser
WORKDIR /app
COPY --from=build /out/quoter-api /app/quoter-api
COPY migrations /app/migrations
COPY seeds /app/seeds

USER appuser
EXPOSE 8080
ENTRYPOINT ["/app/quoter-api"]
