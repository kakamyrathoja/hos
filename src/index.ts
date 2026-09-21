import express, { Request, Response } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';
import apiRoutes from './routes/api';
import { globalLimiter } from './middlewares/rateLimiter';

dotenv.config();

const app = express();
export const prisma = new PrismaClient();

// Middleware
app.set('trust proxy', 1); // Vercel/Cloudflare arkasında gerçek IP için
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));
app.use('/api', globalLimiter);

app.use((req, res, next) => {
  res.setHeader('ngrok-skip-browser-warning', 'true');
  next();
});

// Main Routes
app.use('/api', apiRoutes);

// Basic Route
app.get('/api/health', (req: Request, res: Response) => {
  res.status(200).json({ status: 'success', message: 'Hossarpay Backend is running on Vercel!' });
});

// YENİ: VERCEL UYUMU İÇİN GÜNCELLEME
if (process.env.NODE_ENV !== 'production') {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Hossarpay Server is running on port ${PORT}`);
  });
}

// Vercel serverless export
export default app;