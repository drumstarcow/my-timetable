import { textRecognition } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { OcrLine } from '../common/types';
import { Logger } from '../common/Logger';

/** OCR 结果：带坐标的文本行 + 全文 */
export interface OcrOutcome {
  lines: OcrLine[];
  fullText: string;
}

const TAG = 'OcrService';
const MAX_SIDE = 2048;

/**
 * OCR 服务：图库选图 -> 解码 PixelMap（降采样）-> 系统文字识别。
 * PhotoViewPicker 与 textRecognition 均免权限。
 */
export class OcrService {
  /** 选图并识别；用户取消选图返回 undefined */
  static async pickAndRecognize(): Promise<OcrOutcome | undefined> {
    const uri = await OcrService.pickImage();
    if (uri === undefined) {
      return undefined;
    }
    const pixelMap = await OcrService.uriToPixelMap(uri);
    try {
      return await OcrService.recognize(pixelMap);
    } finally {
      await pixelMap.release();
    }
  }

  private static async pickImage(): Promise<string | undefined> {
    const photoPicker = new photoAccessHelper.PhotoViewPicker();
    const opts: photoAccessHelper.PhotoSelectOptions = {
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    };
    const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select(opts);
    if (result.photoUris.length === 0) {
      return undefined;
    }
    return result.photoUris[0];
  }

  /** uri -> 降采样后的 RGBA PixelMap（OCR 要求 RGBA_8888，createPixelMap 默认即此格式） */
  private static async uriToPixelMap(uri: string): Promise<image.PixelMap> {
    const file = await fs.open(uri, fs.OpenMode.READ_ONLY);
    try {
      const source = image.createImageSource(file.fd);
      try {
        const info = await source.getImageInfo();
        let w = info.size.width;
        let h = info.size.height;
        const maxSide = Math.max(w, h);
        if (maxSide > MAX_SIDE) {
          const ratio = MAX_SIDE / maxSide;
          w = Math.round(w * ratio);
          h = Math.round(h * ratio);
        }
        const opts: image.DecodingOptions = {
          desiredSize: { width: w, height: h }
        };
        return await source.createPixelMap(opts);
      } finally {
        await source.release();
      }
    } finally {
      await fs.close(file.fd);
    }
  }

  /** 识别并展平为行列表（含坐标）。首次失败时尝试 init 后重试一次 */
  static async recognize(pixelMap: image.PixelMap): Promise<OcrOutcome> {
    let info: textRecognition.TextRecognitionResult;
    try {
      info = await OcrService.doRecognize(pixelMap);
    } catch (e) {
      const err = e as BusinessError;
      Logger.warn(TAG, 'recognize failed, retry after init: ' + err.message);
      const ok = await textRecognition.init();
      Logger.info(TAG, 'ocr init result: ' + ok.toString());
      info = await OcrService.doRecognize(pixelMap);
    }

    const lines: OcrLine[] = [];
    for (const block of info.blocks) {
      for (const line of block.lines) {
        const p0 = line.cornerPoints.length > 0 ? line.cornerPoints[0] : null;
        if (p0 === null) {
          continue;
        }
        const p1 = line.cornerPoints.length > 1 ? line.cornerPoints[1] : p0;
        const p2 = line.cornerPoints.length > 2 ? line.cornerPoints[2] : p0;
        const ocrLine: OcrLine = {
          text: line.value,
          x: p0.x,
          y: p0.y,
          w: Math.abs(p1.x - p0.x),
          h: Math.abs(p2.y - p0.y)
        };
        lines.push(ocrLine);
      }
    }
    const outcome: OcrOutcome = { lines: lines, fullText: info.value };
    return outcome;
  }

  private static async doRecognize(pixelMap: image.PixelMap): Promise<textRecognition.TextRecognitionResult> {
    const visionInfo: textRecognition.VisionInfo = { pixelMap: pixelMap };
    return await textRecognition.recognizeText(visionInfo);
  }
}
