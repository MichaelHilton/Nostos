# ---- Stage 1: Build the Go backend ----------------------------------------
FROM golang:1.23-alpine AS backend-builder

# exiftool + build tools
RUN apk add --no-cache gcc musl-dev exiftool

WORKDIR /src/backend
COPY backend/go.mod backend/go.sum ./
RUN go mod download

COPY backend/ ./
RUN CGO_ENABLED=0 GOOS=linux go build -o /photosorter ./cmd/server


# ---- Stage 2: Build the Svelte frontend ------------------------------------
FROM node:20-alpine AS frontend-builder

WORKDIR /src/frontend
COPY frontend/package*.json ./
RUN npm ci

COPY frontend/ ./
RUN npm run build


# ---- Stage 3: Runtime image ------------------------------------------------
FROM alpine:3.20

# exiftool is needed at runtime for RAW metadata extraction
RUN apk add --no-cache exiftool perl

# Copy compiled backend binary
COPY --from=backend-builder /photosorter /usr/local/bin/photosorter

# Copy built frontend assets
COPY --from=frontend-builder /src/frontend/dist /app/frontend/dist

# Default data directories (can be overridden via env / volume mounts)
ENV PHOTOSORTER_DB=/data/photosorter.db \
    PHOTOSORTER_THUMBS=/data/thumbnails \
    PHOTOSORTER_PORT=8080

VOLUME ["/data", "/photos"]

EXPOSE 8080

ENTRYPOINT ["photosorter"]
CMD ["--port", "8080", \
     "--db",   "/data/photosorter.db", \
     "--thumbs", "/data/thumbnails"]
