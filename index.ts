import { PrismaClient } from './generated/prisma'; // Adjust the import path based on your project structure
import express from 'express';

const app = express();
const prisma = new PrismaClient();
app.use(express.json());

console.log('pgsync demo: syncing User and Post tables from db1 to db2');

// Create User
app.post('/users', async (req, res) => {
  const { name, email } = req.body;
  try {
    const user = await prisma.user.create({ data: { name, email } });
    res.json(user);
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
    });
    res.json(user);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Create Post
app.post('/posts', async (req, res) => {
  const { title, content, userId } = req.body;
  try {
    const post = await prisma.post.create({ data: { title, content, userId } });
    res.json(post);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

// Update Post
app.put('/posts/:id', async (req, res) => {
  const { id } = req.params;
  const { title, content } = req.body;
  try {
    const post = await prisma.post.update({
      where: { id: Number(id) },
      data: { title, content },
    });
    res.json(post);
  } catch (err) {
    res
      .status(400)
      .json({ error: err instanceof Error ? err.message : 'Unknown error' });
  }
});

app.listen(3000, () => {
  console.log('Server running on port 3000');
});

// Add your actual sync logic here
