import { Promise } from "rsvp";

export async function fileToImageData(file) {
  let drawable, err;

  // Chrome and Firefox use a native method to do Image -> Bitmap Array (it happens of the main thread!)
  // Safari uses the `<img async>` element due to https://bugs.webkit.org/show_bug.cgi?id=182424
  if ("createImageBitmap" in self) {
    drawable = await createImageBitmap(file);
  } else {
    const url = URL.createObjectURL(file);
    const img = new Image();
    img.decoding = "async";
    img.src = url;
    const loaded = new Promise((resolve, reject) => {
      img.onload = () => resolve();
      img.onerror = () => reject(Error("Image loading error"));
    });

    if (img.decode) {
      // Nice off-thread way supported in Safari/Chrome.
      // Safari throws on decode if the source is SVG.
      // https://bugs.webkit.org/show_bug.cgi?id=188347
      await img.decode().catch(() => null);
    }

    // Always await loaded, as we may have bailed due to the Safari bug above.
    await loaded;

    drawable = img;
  }

  const width = drawable.width,
    height = drawable.height,
    sx = 0,
    sy = 0,
    sw = width,
    sh = height;
  // Make canvas same size as image
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  // Draw image onto canvas
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    err = "Could not create canvas context";
  }
  ctx.drawImage(drawable, sx, sy, sw, sh, 0, 0, width, height);
  const imageData = ctx.getImageData(0, 0, width, height);
  canvas.remove();

  // potentially transparent
  if (/(\.|\/)(png|webp)$/i.test(file.type)) {
    for (let i = 0; i < imageData.data.length; i += 4) {
      if (imageData.data[i + 3] < 255) {
        err = "Image has transparent pixels, won't convert to JPEG!";
        break;
      }
    }
  }

  return { imageData, width, height, err };
}
