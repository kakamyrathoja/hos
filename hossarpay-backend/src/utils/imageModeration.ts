import { RekognitionClient, DetectModerationLabelsCommand } from '@aws-sdk/client-rekognition';

/**
 * Görsel içerik denetimi (Amazon Rekognition detectModerationLabels).
 *
 * Ortam değişkenleri:
 *  - AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY  (Rekognition için)
 *  - AWS_REGION (örn. eu-central-1)
 *  - MODERATION_STRICT=true  → anahtar yoksa yükleme REDDEDİLİR (fail-closed)
 *    MODERATION_STRICT=yok/false → anahtar yoksa geç (fail-open, log yazar)
 *
 * Dönen: { approved: boolean, labels: string[], reason?: string }
 */
export async function moderateImageBase64(base64Data: string): Promise<{
  approved: boolean;
  labels: string[];
  reason?: string;
}> {
  const hasCredentials =
    !!process.env.AWS_ACCESS_KEY_ID && !!process.env.AWS_SECRET_ACCESS_KEY;

  if (!hasCredentials) {
    const strict = process.env.MODERATION_STRICT === 'true';
    if (strict) {
      return { approved: false, labels: [], reason: 'Moderation not configured' };
    }
    // Anahtar yoksa pasif geç (ücretsiz kurulumda uygulama çalışmaya devam eder)
    console.warn('[imageModeration] AWS keys yok, görsel denetim atlandı.');
    return { approved: true, labels: [] };
  }

  // "data:image/jpeg;base64,XXXX" biçiminden ham base64'i ayıkla
  const raw = String(base64Data).split(',').pop() || '';
  let bytes: Buffer;
  try {
    bytes = Buffer.from(raw, 'base64');
  } catch (e) {
    return { approved: true, labels: [] };
  }
  if (bytes.length === 0) return { approved: true, labels: [] };
  // Rekognition en fazla ~5 MB işler — taşarsa güvenli tarafta reddet
  if (bytes.length > 5 * 1024 * 1024) {
    return { approved: false, labels: [], reason: 'Image too large for moderation' };
  }

  try {
    const client = new RekognitionClient({
      region: process.env.AWS_REGION || 'eu-central-1',
    });
    const command = new DetectModerationLabelsCommand({
      Image: { Bytes: bytes },
      MinConfidence: 60,
    });
    const result = await client.send(command);
    const labels = (result.ModerationLabels || []).map((l) => l.Name || '');

    // Yüksek risk kategorileri
    const blockedCategories = ['Explicit Nudity', 'Nudity', 'Violence', 'Graphic Violence', 'Drugs', 'Gambling', 'Sexual Activity', 'Pornography'];
    const hit = labels.find((l) =>
      blockedCategories.some((c) => l.toLowerCase().includes(c.toLowerCase()))
    );

    if (hit) {
      return { approved: false, labels, reason: hit };
    }
    return { approved: true, labels };
  } catch (e: any) {
    console.error('[imageModeration] Rekognition hatası:', e?.message || e);
    // Servis hatası → kullanıcıyı bloklamak yerine pasif geç; ama strict ise reddet
    if (process.env.MODERATION_STRICT === 'true') {
      return { approved: false, labels: [], reason: 'Moderation service error' };
    }
    return { approved: true, labels: [] };
  }
}