/** An image source. Dimensions always describe the source, never its display size. */
export interface BlockImageSource {
  /** Original or managed-upload image URL. */
  url?: string;
  /** How the author selected this source. */
  source?: "upload" | "url";
  /** Managed upload retained with the block layout. */
  upload_id?: number;
  /** Intrinsic source width in pixels. */
  width?: number;
  /** Intrinsic source height in pixels. */
  height?: number;
}

/** Composition shared by the light and dark sources. */
export interface ImageComposition {
  /** Cover fills and crops the frame; contain preserves the entire image. */
  fit: "cover" | "contain";
  /** Physical image alignment within the frame. */
  position: {
    /** Percentage from the left edge, between 0 and 100. */
    x: number;
    /** Percentage from the top edge, between 0 and 100. */
    y: number;
  };
  /** Magnification beyond the chosen fit, between 100 and 250 percent. */
  zoom: number;
}

/** An image argument with independent source metadata and optional authored frame. */
export interface BlockImageValue
  extends BlockImageSource, Partial<ImageComposition> {
  /** Alternative source using the same frame and composition in dark mode. */
  dark?: BlockImageSource;
  /** Optional author sizing, ignored by grid-owned and background frames. */
  frame?: {
    /** Authored frame width in CSS pixels. */
    width: number;
    /** Authored frame height in CSS pixels. */
    height: number;
  };
}

export function imageComposition(
  value?: Partial<ImageComposition> | null
): ImageComposition {
  return {
    fit: value?.fit === "contain" ? "contain" : "cover",
    position: {
      x: boundedImageNumber(value?.position?.x, 0, 100, 50),
      y: boundedImageNumber(value?.position?.y, 0, 100, 50),
    },
    zoom: boundedImageNumber(value?.zoom, 100, 250, 100),
  };
}

export function boundedImageNumber(
  value: unknown,
  min: number,
  max: number,
  fallback: number
): number {
  return typeof value === "number" && Number.isFinite(value)
    ? Math.min(max, Math.max(min, value))
    : fallback;
}

/** Safe numeric-only declarations, also used by transient previews. */
export function imageCompositionStyle(
  value?: Partial<ImageComposition> | null
): string {
  const { fit, position, zoom } = imageComposition(value);
  return `--block-image-fit: ${fit}; --block-image-position: ${position.x}% ${position.y}%; --block-image-zoom: ${zoom / 100};`;
}

/** Replaces source metadata without losing composition, frame, or the other variant. */
export function replaceImageSource(
  value: BlockImageValue | null | undefined,
  source: BlockImageSource,
  variant: "light" | "dark" = "light"
): BlockImageValue {
  if (variant === "dark") {
    return { ...value, dark: source };
  }
  const { dark, fit, position, zoom, frame } = value ?? {};
  return {
    ...source,
    ...(dark && { dark }),
    ...(fit && { fit }),
    ...(position && { position }),
    ...(zoom && { zoom }),
    ...(frame && { frame }),
  };
}

/** Returns the first invalid composition field, before values reach a renderer. */
export function invalidImageCompositionField(
  value: Record<string, unknown>
): string | undefined {
  if (
    value.fit !== undefined &&
    value.fit !== "cover" &&
    value.fit !== "contain"
  ) {
    return "fit";
  }
  if (
    value.zoom !== undefined &&
    (typeof value.zoom !== "number" ||
      !Number.isFinite(value.zoom) ||
      value.zoom < 100 ||
      value.zoom > 250)
  ) {
    return "zoom";
  }
  for (const field of ["position", "frame"] as const) {
    const object = value[field];
    if (object === undefined) {
      continue;
    }
    if (!object || typeof object !== "object" || Array.isArray(object)) {
      return field;
    }
    const keys = field === "position" ? ["x", "y"] : ["width", "height"];
    for (const key of keys) {
      const number = (object as Record<string, unknown>)[key];
      if (
        typeof number !== "number" ||
        !Number.isFinite(number) ||
        (field === "position" ? number < 0 || number > 100 : number <= 0)
      ) {
        return `${field}.${key}`;
      }
    }
  }
}
