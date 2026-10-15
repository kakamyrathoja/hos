/**
 * Basit metin denetimi (yasaklı kelime listesi).
 * AWS anahtarı olmadan da çalışır — ücretsiz, anında.
 * Küçük harf + Türkçe karakter normalizasyonu ile eşleştirir.
 *
 * Dönen: { approved: boolean, matched?: string }
 */
const BANNED_WORDS = [
  'fuck', 'shit', 'bitch', 'asshole', 'nigger', 'whore',
  'sex video', 'porn', 'casino', 'kumar', 'bahis', 'bet',
  'viagra', 'escort', 'telegram bot satılık', 'hack', 'crack',
];

function normalize(text: string): string {
  return String(text)
    .toLowerCase()
    .replace(/ı/g, 'i')
    .replace(/ş/g, 's')
    .replace(/ç/g, 'c')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ö/g, 'o')
    .replace(/â/g, 'a')
    .replace(/î/g, 'i')
    .replace(/û/g, 'u')
    .replace(/ё/g, 'е')
    .replace(/й/g, 'i');
}

export function moderateText(text: string): { approved: boolean; matched?: string } {
  if (!text) return { approved: true };
  const normalized = normalize(text);
  for (const word of BANNED_WORDS) {
    if (normalized.includes(normalize(word))) {
      return { approved: false, matched: word };
    }
  }
  return { approved: true };
}