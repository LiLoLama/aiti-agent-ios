const FALLBACK_MAX_DIMENSION = 1024;
const DEFAULT_QUALITY = 0.85;
const DEFAULT_MIME_TYPE = 'image/jpeg';

function readFileAsDataURL(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('Datei konnte nicht gelesen werden.'));
    reader.onload = () => {
      if (typeof reader.result === 'string') {
        resolve(reader.result);
      } else {
        reject(new Error('Ungültiges Datei-Format.'));
      }
    };

    reader.readAsDataURL(file);
  });
}

function loadImageElement(source: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error('Bild konnte nicht geladen werden.'));
    image.src = source;
  });
}

export interface ImagePreparationOptions {
  maxDimension?: number;
  mimeType?: string;
  quality?: number;
}

export async function prepareImageForStorage(
  file: File,
  options: ImagePreparationOptions = {}
): Promise<string> {
  const dataUrl = await readFileAsDataURL(file);

  if (typeof window === 'undefined' || !dataUrl.startsWith('data:image')) {
    return dataUrl;
  }

  try {
    const image = await loadImageElement(dataUrl);
    const { width, height } = image;

    if (!width || !height) {
      return dataUrl;
    }

    const maxDimension = Math.max(options.maxDimension ?? FALLBACK_MAX_DIMENSION, 1);
    const longestEdge = Math.max(width, height);

    if (longestEdge <= maxDimension) {
      return dataUrl;
    }

    const scale = maxDimension / longestEdge;
    const targetWidth = Math.round(width * scale);
    const targetHeight = Math.round(height * scale);

    const canvas = document.createElement('canvas');
    canvas.width = targetWidth;
    canvas.height = targetHeight;

    const context = canvas.getContext('2d');
    if (!context) {
      return dataUrl;
    }

    context.drawImage(image, 0, 0, targetWidth, targetHeight);

    const mimeType = options.mimeType ?? DEFAULT_MIME_TYPE;
    const quality = options.quality ?? DEFAULT_QUALITY;

    let compressed = canvas.toDataURL(mimeType, quality);

    if (mimeType !== 'image/png' && compressed.startsWith('data:image/png')) {
      compressed = canvas.toDataURL(DEFAULT_MIME_TYPE, quality);
    }

    return compressed.length < dataUrl.length ? compressed : dataUrl;
  } catch (error) {
    console.warn('Konnte Bild nicht komprimieren, verwende Original.', error);
    return dataUrl;
  }
}
