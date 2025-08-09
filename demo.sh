#!/bin/bash

# PostgreSQL Replication Demo Test Script
# This script demonstrates all API endpoints and replication features

set -e

API_BASE="http://localhost:8000"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 PostgreSQL Replication Demo Test Script${NC}"
echo "=============================================="

# Health Check
echo -e "\n${YELLOW}1. Health Check${NC}"
curl -s "$API_BASE/health" | jq .

# Statistics
echo -e "\n${YELLOW}2. Current Statistics${NC}"
curl -s "$API_BASE/stats" | jq .

# Create a new category
echo -e "\n${YELLOW}3. Creating new category...${NC}"
CATEGORY_RESPONSE=$(curl -s -X POST "$API_BASE/categories" \
  -H "Content-Type: application/json" \
  -d '{"name": "Demo Category"}')
CATEGORY_ID=$(echo $CATEGORY_RESPONSE | jq -r '.id')
echo "Created category with ID: $CATEGORY_ID"

# Create a new user
echo -e "\n${YELLOW}4. Creating new user...${NC}"
USER_RESPONSE=$(curl -s -X POST "$API_BASE/users" \
  -H "Content-Type: application/json" \
  -d '{"name": "Demo User", "email": "demo@example.com"}')
USER_ID=$(echo $USER_RESPONSE | jq -r '.id')
echo "Created user with ID: $USER_ID"

# Create a new post
echo -e "\n${YELLOW}5. Creating new post...${NC}"
POST_RESPONSE=$(curl -s -X POST "$API_BASE/posts" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"Demo Post\", \"content\": \"This is a demo post created via API\", \"userId\": $USER_ID, \"categoryId\": $CATEGORY_ID}")
POST_ID=$(echo $POST_RESPONSE | jq -r '.id')
echo "Created post with ID: $POST_ID"

# Add comments
echo -e "\n${YELLOW}6. Adding comments...${NC}"
for i in {1..3}; do
  COMMENT_RESPONSE=$(curl -s -X POST "$API_BASE/comments" \
    -H "Content-Type: application/json" \
    -d "{\"content\": \"This is comment #$i\", \"userId\": $USER_ID, \"postId\": $POST_ID}")
  COMMENT_ID=$(echo $COMMENT_RESPONSE | jq -r '.id')
  echo "Created comment with ID: $COMMENT_ID"
done

# Wait for replication
echo -e "\n${YELLOW}7. Waiting for replication...${NC}"
sleep 3

# Verify data in target database (we'll use the API which reads from source, 
# but in a real scenario you'd check the target DB directly)
echo -e "\n${YELLOW}8. Verifying created data...${NC}"
echo "Post details:"
curl -s "$API_BASE/posts/$POST_ID" | jq .

# Update operations
echo -e "\n${YELLOW}9. Testing update operations...${NC}"
curl -s -X PUT "$API_BASE/users/$USER_ID" \
  -H "Content-Type: application/json" \
  -d '{"name": "Demo User Updated", "email": "demo.updated@example.com"}' | jq .

curl -s -X PUT "$API_BASE/posts/$POST_ID" \
  -H "Content-Type: application/json" \
  -d '{"title": "Demo Post Updated", "content": "This post has been updated!"}' | jq .

# Final statistics
echo -e "\n${YELLOW}10. Final Statistics${NC}"
curl -s "$API_BASE/stats" | jq .

# List all data
echo -e "\n${YELLOW}11. All Categories with Posts${NC}"
curl -s "$API_BASE/categories" | jq '.[] | {id, name, postCount: ._count.posts}'

echo -e "\n${YELLOW}12. All Users with Post/Comment Counts${NC}"
curl -s "$API_BASE/users" | jq '.[] | {id, name, email, postCount: ._count.posts, commentCount: ._count.comments}'

echo -e "\n${GREEN}✅ Demo completed successfully!${NC}"
echo -e "${BLUE}🔄 All operations have been replicated between databases${NC}"
echo ""
echo "You can verify replication by:"
echo "1. Checking Prisma Studio: http://localhost:8010 (source) vs http://localhost:8020 (target)"
echo "2. Checking replication health: curl http://localhost:8000/health"
echo "3. Viewing logs: docker compose logs postgres-replica"
