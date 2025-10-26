#!/bin/bash

# Currency Converter - Setup Script
# This script helps you set up the project for local development

set -e

echo "========================================"
echo "Currency Converter - Setup Script"
echo "========================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file from .env.example...${NC}"
    cp .env.example .env
    echo -e "${GREEN}✓ .env file created${NC}"
    echo -e "${YELLOW}Please edit .env and add your API keys${NC}"
    echo ""
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

# Check Docker
echo "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    echo "Please install Docker from https://docs.docker.com/get-docker/"
    exit 1
fi
echo -e "${GREEN}✓ Docker is installed${NC}"

# Check Docker Compose
echo "Checking Docker Compose installation..."
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}✗ Docker Compose is not installed${NC}"
    echo "Please install Docker Compose from https://docs.docker.com/compose/install/"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose is installed${NC}"

# Check Java
echo "Checking Java installation..."
if ! command -v java &> /dev/null; then
    echo -e "${YELLOW}⚠ Java is not installed${NC}"
    echo "Install Java 17+ for local development (optional if using Docker)"
else
    JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}')
    echo -e "${GREEN}✓ Java $JAVA_VERSION is installed${NC}"
fi

# Check Maven
echo "Checking Maven installation..."
if ! command -v mvn &> /dev/null; then
    echo -e "${YELLOW}⚠ Maven is not installed${NC}"
    echo "Install Maven for local development (optional if using Docker)"
else
    MVN_VERSION=$(mvn -version | head -n 1)
    echo -e "${GREEN}✓ $MVN_VERSION${NC}"
fi

# Check Node.js
echo "Checking Node.js installation..."
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}⚠ Node.js is not installed${NC}"
    echo "Install Node.js 18+ for local development (optional if using Docker)"
else
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓ Node.js $NODE_VERSION is installed${NC}"
fi

# Check npm
if command -v npm &> /dev/null; then
    NPM_VERSION=$(npm -v)
    echo -e "${GREEN}✓ npm $NPM_VERSION is installed${NC}"
fi

echo ""
echo "========================================"
echo "Setup Options"
echo "========================================"
echo ""
echo "1. Docker Setup (Recommended)"
echo "2. Local Development Setup"
echo "3. Exit"
echo ""
read -p "Choose an option (1-3): " option

case $option in
    1)
        echo ""
        echo "Setting up with Docker..."
        echo ""
        
        # Build and start services
        echo "Building Docker images..."
        docker-compose build
        
        echo ""
        echo "Starting services..."
        docker-compose up -d
        
        echo ""
        echo "Waiting for services to be ready..."
        sleep 10
        
        # Check service health
        echo "Checking service health..."
        docker-compose ps
        
        echo ""
        echo -e "${GREEN}✓ Setup complete!${NC}"
        echo ""
        echo "Services running:"
        echo "  - Frontend: http://localhost:3000"
        echo "  - Backend API: http://localhost:8080"
        echo "  - PostgreSQL: localhost:5432"
        echo "  - Redis: localhost:6379"
        echo ""
        echo "To view logs: docker-compose logs -f"
        echo "To stop services: docker-compose down"
        ;;
        
    2)
        echo ""
        echo "Setting up for local development..."
        echo ""
        
        # Start only databases with Docker
        echo "Starting PostgreSQL and Redis..."
        docker-compose up -d postgres redis
        
        echo ""
        echo "Waiting for databases to be ready..."
        sleep 5
        
        # Backend setup
        if command -v mvn &> /dev/null; then
            echo ""
            echo "Setting up backend..."
            cd backend
            mvn clean install -DskipTests
            echo -e "${GREEN}✓ Backend built successfully${NC}"
            echo ""
            echo "To start backend:"
            echo "  cd backend"
            echo "  mvn spring-boot:run"
            cd ..
        else
            echo -e "${YELLOW}⚠ Maven not found. Skip backend build.${NC}"
        fi
        
        # Frontend setup
        if command -v npm &> /dev/null; then
            echo ""
            echo "Setting up frontend..."
            cd frontend
            npm install
            echo -e "${GREEN}✓ Frontend dependencies installed${NC}"
            echo ""
            echo "To start frontend:"
            echo "  cd frontend"
            echo "  npm run dev"
            cd ..
        else
            echo -e "${YELLOW}⚠ npm not found. Skip frontend setup.${NC}"
        fi
        
        echo ""
        echo -e "${GREEN}✓ Local development setup complete!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Update .env with your API keys"
        echo "  2. Start backend: cd backend && mvn spring-boot:run"
        echo "  3. Start frontend: cd frontend && npm run dev"
        echo "  4. Access: http://localhost:3000"
        ;;
        
    3)
        echo "Exiting..."
        exit 0
        ;;
        
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo ""
echo "========================================"
echo "Important Information"
echo "========================================"
echo ""
echo "Test Credentials:"
echo "  Email: demo@example.com"
echo "  Password: password123"
echo ""
echo "API Keys Required:"
echo "  - Exchange Rates API: https://exchangeratesapi.io/"
echo "  - News API: https://newsapi.org/"
echo "  - Crypto API: https://www.coingecko.com/ (optional)"
echo ""
echo "Documentation:"
echo "  - Backend README: backend/README.md"
echo "  - Frontend README: frontend/README.md"
echo "  - API Docs: http://localhost:8080/swagger-ui.html"
echo ""
echo "For more information, see README.md"
echo ""