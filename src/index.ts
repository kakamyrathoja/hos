import express, { Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import apiRoutes from './routes/api';
import path from 'path';
import fs from 'fs';

// MANUEL ENV YÜKLEME
const envPath = path.resolve(__dirname, '../.env');
console.log('[ENV] Loading from:', envPath);

if (fs.existsSync(envPath)) {
  const envContent = fs.readFileSync(envPath, 'utf-8');
  console.log('[ENV] File size:', envContent.length, 'bytes');
  const result = dotenv.parse(envContent);
  console.log('[ENV] Parsed keys:', Object.keys(result));
  for (const key in result) {
    process.env[key] = result[key];
  }
  console.log('[ENV] ✓ Loaded', Object.keys(result).length, 'variables');
} else {
  console.log('[ENV] ✗ File not found!');
}

const app = express();
export const prisma = new PrismaClient();

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

app.use((req, res, next) => {
  res.setHeader('ngrok-skip-browser-warning', 'true');
  next();
});

// Main Routes
app.use('/api', apiRoutes);

// Basic Route
app.get('/api/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'success', message: 'Hossarpay Backend is running on VPS!' });
});

// YENİ: VERCEL UYUMU İÇİN GÜNCELLEME
if (process.env.NODE_ENV !== 'production') {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Hossarpay Server is running on port ${PORT}`);
  });
}

export default app;