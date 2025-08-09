# PostgreSQL Real-time Replication Demo

A comprehensive demonstration of PostgreSQL logical replication with real-time data synchronization between multiple databases using Docker, Prisma, and a custom replication service.

## 🚀 Features

- **Real-time PostgreSQL Logical Replication** between multiple databases
- **Automatic Schema Detection** - Dynamically detects and replicates new tables
- **Health Monitoring** - Built-in health checks and replication status monitoring
- **RESTful API** - Complete CRUD operations for all entities
- **Docker Compose Setup** - Fully containerized environment
- **Prisma ORM Integration** - Type-safe database operations
- **Multi-table Support** - Users, Posts, Comments, and Categories with relationships

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Source DB     │    │  Replication     │    │   Target DB     │
│   (postgres1)   │───▶│    Service       │───▶│   (postgres2)   │
│   Port: 5432    │    │  (postgres-      │    │   Port: 5433    │
│                 │    │   replica)       │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  DB1 Manager    │    │   API Backend    │    │  DB2 Manager    │
│ (Prisma Studio) │    │  (Express API)   │    │ (Prisma Studio) │
│  Port: 8010     │    │   Port: 8000     │    │  Port: 8020     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 📋 Prerequisites

- Docker and Docker Compose
- Node.js 20+ (for local development)
- curl (for testing)

## 🚦 Quick Start

### 1. Clone and Start Services

```bash
# Clone the repository
git clone <repository-url>
cd db-sync-test

# Start all services
docker compose up -d

# Check service status
docker compose ps
```

### 2. Verify Health

```bash
# Check API health
curl http://localhost:8000/health

# Check replication health
curl http://localhost:8000/health | jq

# View database statistics
curl http://localhost:8000/stats
```

### 3. Access Management Interfaces

- **API Documentation**: http://localhost:8000
- **Source DB (Prisma Studio)**: http://localhost:8010
- **Target DB (Prisma Studio)**: http://localhost:8020
- **Replication Health**: http://localhost:8000/health

## 🔧 Services

| Service | Port | Description |
|---------|------|-------------|
| `postgres1` | 5432 | Source PostgreSQL database |
| `postgres2` | 5433 | Target PostgreSQL database |
| `db1-manager` | 8010 | Prisma Studio for source DB |
| `db2-manager` | 8020 | Prisma Studio for target DB |
| `postgres-replica` | 3000 | Replication service with health endpoint |
| `api-backend` | 8000 | Express API server |

## 📡 API Endpoints

### Health & Analytics
- `GET /health` - Service health check
- `GET /stats` - Database statistics

### Users
- `GET /users` - List all users with posts and comments
- `GET /users/:id` - Get user by ID with detailed relationships
- `POST /users` - Create new user
- `PUT /users/:id` - Update user
- `DELETE /users/:id` - Delete user

### Posts
- `GET /posts` - List all posts with authors, categories, and comments
- `GET /posts/:id` - Get post by ID with full details
- `POST /posts` - Create new post
- `PUT /posts/:id` - Update post
- `DELETE /posts/:id` - Delete post
- `GET /posts/:postId/comments` - Get all comments for a post

### Comments
- `GET /comments` - List all comments with authors and posts
- `POST /comments` - Create new comment
- `PUT /comments/:id` - Update comment
- `DELETE /comments/:id` - Delete comment

### Categories
- `GET /categories` - List all categories with posts
- `GET /categories/:id` - Get category by ID with posts
- `POST /categories` - Create new category
- `PUT /categories/:id` - Update category
- `DELETE /categories/:id` - Delete category

## 🧪 Testing Replication

### Basic Replication Test

```bash
# 1. Create a user in source database
curl -X POST http://localhost:8000/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'

# 2. Create a category
curl -X POST http://localhost:8000/categories \
  -H "Content-Type: application/json" \
  -d '{"name": "Technology"}'

# 3. Create a post
curl -X POST http://localhost:8000/posts \
  -H "Content-Type: application/json" \
  -d '{"title": "My First Post", "content": "Hello World!", "userId": 1, "categoryId": 1}'

# 4. Add a comment
curl -X POST http://localhost:8000/comments \
  -H "Content-Type: application/json" \
  -d '{"content": "Great post!", "userId": 1, "postId": 1}'

# 5. Verify data in both databases
curl http://localhost:8000/posts/1
```

### Advanced Testing

```bash
# Test bulk operations
for i in {1..5}; do
  curl -X POST http://localhost:8000/users \
    -H "Content-Type: application/json" \
    -d "{\"name\": \"User $i\", \"email\": \"user$i@example.com\"}"
done

# Update operations
curl -X PUT http://localhost:8000/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe Updated", "email": "john.updated@example.com"}'

# Delete operations
curl -X DELETE http://localhost:8000/comments/1
```

## 🗃️ Database Schema

```sql
-- Users table
CREATE TABLE "User" (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL
);

-- Categories table  
CREATE TABLE "Category" (
  id SERIAL PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);

-- Posts table
CREATE TABLE "Post" (
  id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  "userId" INTEGER NOT NULL REFERENCES "User"(id),
  "categoryId" INTEGER REFERENCES "Category"(id)
);

-- Comments table
CREATE TABLE "Comment" (
  id SERIAL PRIMARY KEY,
  content TEXT NOT NULL,
  "userId" INTEGER NOT NULL REFERENCES "User"(id),
  "postId" INTEGER NOT NULL REFERENCES "Post"(id)
);
```

## 🔄 Replication Configuration

The replication service uses PostgreSQL logical replication with the following configuration:

```yaml
# replication-config.yml
replication:
  publication_name: "my_publication"
  
  source:
    host: "postgres1"
    port: 5432
    user: "user1" 
    password: "pass1"
    database: "db1"
    
  targets:
    - name: "primary_replica"
      subscription_name: "my_subscription"
      host: "postgres2"
      port: 5432
      user: "user2"
      password: "pass2" 
      database: "db2"
      
  tables:
    - "User"
    - "Post"
    - "Comment"
    - "Category"
```

## 🛠️ Development

### Adding New Tables

1. **Update Prisma Schema**:
   ```prisma
   model NewTable {
     id    Int    @id @default(autoincrement())
     name  String
     // ... other fields
   }
   ```

2. **Create and Apply Migration**:
   ```bash
   docker exec db-sync-test-db1-manager-1 npx prisma migrate dev --name add_new_table
   docker exec db-sync-test-db2-manager-1 npx prisma migrate deploy
   ```

3. **Update Replication Config**:
   ```yaml
   tables:
     - "User"
     - "Post" 
     - "Comment"
     - "Category"
     - "NewTable"  # Add new table
   ```

4. **Restart Replication Service**:
   ```bash
   docker compose restart postgres-replica
   ```

The replication service will automatically detect and configure the new table!

### Local Development

```bash
# Install dependencies
npm install

# Generate Prisma client
npx prisma generate

# Run development server
npm run dev
```

## 📊 Monitoring

### Health Checks

```bash
# API Health
curl http://localhost:8000/health

# Replication Health  
curl http://localhost:8000/health

# Database Statistics
curl http://localhost:8000/stats
```

### Logs

```bash
# View all logs
docker compose logs

# View specific service logs
docker compose logs postgres-replica
docker compose logs api-backend

# Follow logs in real-time
docker compose logs -f postgres-replica
```

### Database Access

```bash
# Connect to source database
docker exec -it postgres1 psql -U user1 -d db1

# Connect to target database  
docker exec -it postgres2 psql -U user2 -d db2

# Check replication status
docker exec postgres1 psql -U user1 -d db1 -c "SELECT * FROM pg_publication_tables;"
docker exec postgres2 psql -U user2 -d db2 -c "SELECT * FROM pg_subscription;"
```

## 🚨 Troubleshooting

### Common Issues

**1. P3005 Migration Error**
```bash
# Reset databases and restart
docker compose down -v
docker compose up -d
```

**2. Replication Not Working**
```bash
# Check replication service logs
docker compose logs postgres-replica

# Verify publication
docker exec postgres1 psql -U user1 -d db1 -c "SELECT * FROM pg_publication_tables;"

# Restart replication
docker compose restart postgres-replica
```

**3. Health Check Failing**
```bash
# Check service status
docker compose ps

# Rebuild images
docker compose build
docker compose up -d
```

### Reset Everything

```bash
# Complete reset
docker compose down -v
docker compose build
docker compose up -d
```

## 🔒 Security Notes

- This is a development/demo setup
- Default passwords are used for simplicity
- In production, use secure passwords and SSL connections
- Configure proper network security and access controls

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details

## 🙋‍♂️ Support

For issues and questions:
1. Check the troubleshooting section
2. Review logs: `docker compose logs`
3. Open an issue on GitHub

---

**Happy Replicating! 🚀**
