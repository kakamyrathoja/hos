import { S3Client, PutObjectCommand, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import crypto from 'crypto';

const s3Client = new S3Client({
  region: process.env.AWS_REGION || 'eu-central-003',
  endpoint: process.env.AWS_ENDPOINT,
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
  forcePathStyle: true,
});

const BUCKET = process.env.AWS_BUCKET || 'hossarpay-media';

// Dosya yükle
export const uploadToStorage = async (
  buffer: Buffer,
  originalName: string,
  mimeType: string,
  folder: string = 'general'
): Promise<string> => {
  const ext = originalName.split('.').pop() || 'bin';
  const randomName = crypto.randomBytes(16).toString('hex');
  const key = `${folder}/${randomName}.${ext}`;

  await s3Client.send(new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    Body: buffer,
    ContentType: mimeType,
    ACL: 'public-read', // B2'de gerekli olmayabilir
  }));

  return key;
};

// Signed URL (geçici erişim) üret
export const getSignedFileUrl = async (key: string, expiresIn: number = 3600): Promise<string> => {
  const command = new GetObjectCommand({
    Bucket: BUCKET,
    Key: key,
  });
  return await getSignedUrl(s3Client, command, { expiresIn });
};

// Dosya sil
export const deleteFromStorage = async (key: string): Promise<void> => {
  await s3Client.send(new DeleteObjectCommand({
    Bucket: BUCKET,
    Key: key,
  }));
};

// Mevcut public URL'leri signed URL'e çevir
export const getSignedUrlFromKey = getSignedFileUrl;