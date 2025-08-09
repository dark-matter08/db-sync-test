import { PrismaClient } from './generated/prisma';
import express from 'express';

const app = express();
const prisma = new PrismaClient();
app.use(express.json());

console.log('PostgreSQL Replication Demo: Real-time sync between db1 and db2');
console.log('API Server starting on port 3000...');

// Health check endpoint
app.get('/health', async (req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
  } catch (err) {
    res.status(500).json({
      status: 'unhealthy',
      error: err instanceof Error ? err.message : 'Unknown error',
      timestamp: new Date().toISOString(),
    });
  }
});

// ========== USER ENDPOINTS ==========

// Get all users
app.get('/users', async (req, res) => {
  try {
    const users = await prisma.user.findMany({
      include: {
        posts: {
          include: {
            category: true,
            _count: { select: { comments: true } },
          },
        },
        comments: true,
        _count: { select: { posts: true, comments: true } },
      },
    });
    res.json(users);
  } catch (err) {
    res
      .status(500)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Get user by ID
app.get('/users/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const user = await prisma.user.findUnique({
      where: { id: Number(id) },
      include: {
        posts: {
          include: {
            category: true,
            comments: { include: { user: { select: { name: true } } } },
          },
        },
        comments: { include: { post: { select: { title: true } } } },
      },
    });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(user);
  } catch (err) {
    res
      .status(500)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Create User
app.post('/users', async (req, res) => {
  const { name, email } = req.body;
  try {
    const user = await prisma.user.create({
      data: { name, email },
      include: {
        _count: { select: { posts: true, comments: true } },
      },
    });
    res.status(201).json(user);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Update User
app.put('/users/:id', async (req, res) => {
  const { id } = req.params;
  const { name, email } = req.body;
  try {
    const user = await prisma.user.update({
      where: { id: Number(id) },
      data: { name, email },
      include: {
        _count: { select: { posts: true, comments: true } },
      },
    });
    res.json(user);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Delete User
app.delete('/users/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await prisma.user.delete({
      where: { id: Number(id) },
    });
    res.status(204).send();
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// ========== POST ENDPOINTS ==========

// Get all posts
app.get('/posts', async (req, res) => {
  try {
    const posts = await prisma.post.findMany({
      include: {
        user: { select: { id: true, name: true, email: true } },
        category: true,
        comments: {
          include: {
            user: { select: { id: true, name: true } },
          },
        },
        _count: { select: { comments: true } },
      },
      orderBy: { id: 'desc' },
    });
    res.json(posts);
  } catch (err) {
    res
      .status(500)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Get post by ID
app.get('/posts/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const post = await prisma.post.findUnique({
      where: { id: Number(id) },
      include: {
        user: { select: { id: true, name: true, email: true } },
        category: true,
        comments: {
          include: {
            user: { select: { id: true, name: true } },
          },
          orderBy: { id: 'asc' },
        },
      },
    });
    if (!post) {
      return res.status(404).json({ error: 'Post not found' });
    }
    res.json(post);
  } catch (err) {
    res
      .status(500)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Create Post
app.post('/posts', async (req, res) => {
  const { title, content, userId, categoryId } = req.body;
  try {
    const post = await prisma.post.create({
      data: { title, content, userId, categoryId },
      include: {
        user: { select: { id: true, name: true } },
        category: true,
        _count: { select: { comments: true } },
      },
    });
    res.status(201).json(post);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Update Post
app.put('/posts/:id', async (req, res) => {
  const { id } = req.params;
  const { title, content, categoryId } = req.body;
  try {
    const post = await prisma.post.update({
      where: { id: Number(id) },
      data: { title, content, categoryId },
      include: {
        user: { select: { id: true, name: true } },
        category: true,
        _count: { select: { comments: true } },
      },
    });
    res.json(post);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Delete Post
app.delete('/posts/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await prisma.post.delete({
      where: { id: Number(id) },
    });
    res.status(204).send();
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// ========== COMMENT ENDPOINTS ==========

// Get all comments
app.get('/comments', async (req, res) => {
  try {
    const comments = await prisma.comment.findMany({
      include: {
        user: { select: { id: true, name: true } },
        post: { select: { id: true, title: true } },
      },
      orderBy: { id: 'desc' },
    });
    res.json(comments);
  } catch (err) {
    res
      .status(500)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Get comments for a specific post
app.get('/posts/:postId/comments', async (req, res) => {
  const { postId } = req.params;
  try {
    const comments = await prisma.comment.findMany({
      where: { postId: Number(postId) },
      include: {
        user: { select: { id: true, name: true } },
      },
      orderBy: { id: 'asc' },
    });
    res.json(comments);
  } catch (err) {
    res
      .status(500)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Create Comment
app.post('/comments', async (req, res) => {
  const { content, userId, postId } = req.body;
  try {
    const comment = await prisma.comment.create({
      data: { content, userId, postId },
      include: {
        user: { select: { id: true, name: true } },
        post: { select: { id: true, title: true } },
      },
    });
    res.status(201).json(comment);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Update Comment
app.put('/comments/:id', async (req, res) => {
  const { id } = req.params;
  const { content } = req.body;
  try {
    const comment = await prisma.comment.update({
      where: { id: Number(id) },
      data: { content },
      include: {
        user: { select: { id: true, name: true } },
        post: { select: { id: true, title: true } },
      },
    });
    res.json(comment);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Delete Comment
app.delete('/comments/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await prisma.comment.delete({
      where: { id: Number(id) },
    });
    res.status(204).send();
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// ========== CATEGORY ENDPOINTS ==========

// Get all categories
app.get('/categories', async (req, res) => {
  try {
    const categories = await prisma.category.findMany({
      include: {
        posts: {
          include: {
            user: { select: { id: true, name: true } },
            _count: { select: { comments: true } },
          },
        },
        _count: { select: { posts: true } },
      },
      orderBy: { name: 'asc' },
    });
    res.json(categories);
  } catch (err) {
    res
      .status(500)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Get category by ID
app.get('/categories/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const category = await prisma.category.findUnique({
      where: { id: Number(id) },
      include: {
        posts: {
          include: {
            user: { select: { id: true, name: true } },
            comments: {
              include: {
                user: { select: { id: true, name: true } },
              },
            },
          },
        },
      },
    });
    if (!category) {
      return res.status(404).json({ error: 'Category not found' });
    }
    res.json(category);
  } catch (err) {
    res
      .status(500)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Create Category
app.post('/categories', async (req, res) => {
  const { name } = req.body;
  try {
    const category = await prisma.category.create({
      data: { name },
      include: {
        _count: { select: { posts: true } },
      },
    });
    res.status(201).json(category);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Update Category
app.put('/categories/:id', async (req, res) => {
  const { id } = req.params;
  const { name } = req.body;
  try {
    const category = await prisma.category.update({
      where: { id: Number(id) },
      data: { name },
      include: {
        _count: { select: { posts: true } },
      },
    });
    res.json(category);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Delete Category
app.delete('/categories/:id', async (req, res) => {
  const { id } = req.params;
  try {
    await prisma.category.delete({
      where: { id: Number(id) },
    });
    res.status(204).send();
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// ========== ANALYTICS ENDPOINTS ==========

// Get database statistics
app.get('/stats', async (req, res) => {
  try {
    const stats = await prisma.$transaction([
      prisma.user.count(),
      prisma.post.count(),
      prisma.comment.count(),
      prisma.category.count(),
    ]);

    const [userCount, postCount, commentCount, categoryCount] = stats;

    res.json({
      users: userCount,
      posts: postCount,
      comments: commentCount,
      categories: categoryCount,
      timestamp: new Date().toISOString(),
    });
  } catch (err) {
    res
      .status(500)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

app.listen(3000, () => {
  console.log('🚀 API Server running on port 3000');
  console.log('📊 Available endpoints:');
  console.log('  Health: GET /health');
  console.log('  Users: GET,POST /users | GET,PUT,DELETE /users/:id');
  console.log('  Posts: GET,POST /posts | GET,PUT,DELETE /posts/:id');
  console.log('  Comments: GET,POST /comments | GET,PUT,DELETE /comments/:id');
  console.log(
    '  Categories: GET,POST /categories | GET,PUT,DELETE /categories/:id'
  );
  console.log('  Analytics: GET /stats');
  console.log('  Post Comments: GET /posts/:postId/comments');
  console.log('🔄 PostgreSQL replication active between db1 → db2');
});

// Graceful shutdown
process.on('SIGINT', async () => {
  console.log('\n🔄 Shutting down gracefully...');
  await prisma.$disconnect();
  process.exit(0);
});
