async function fileToDrawable(file) {
  return await createImageBitmap(file);
}

function drawableToImageData(drawable) {
  const width = drawable.width,
    height = drawable.height,
    sx = 0,
    sy = 0,
    sw = width,
    sh = height;

  let canvas = new OffscreenCanvas(width, height);

  // Draw image onto canvas
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw "Could not create canvas context";
  }
  ctx.drawImage(drawable, sx, sy, sw, sh, 0, 0, width, height);
  const imageData = ctx.getImageData(0, 0, width, height);

  // Safari shenanigans
  canvas.width = canvas.height = 0;

  return imageData;
}

function isTransparent(type, imageData) {
  if (!/(\.|\/)(png|webp)$/i.test(type)) {
    return false;
  }

  for (let i = 0; i < imageData.data.length; i += 4) {
    if (imageData.data[i + 3] < 255) {
      return true;
    }
  }

  return false;
}

function jpegDecodeFailure(type, imageData) {
  if (!/(\.|\/)jpe?g$/i.test(type)) {
    return false;
  }

  return imageData.data[3] === 0;
}

export async function fileToImageData(file) {
  const drawable = await fileToDrawable(file);
  const imageData = drawableToImageData(drawable);

  if (isTransparent(file.type, imageData)) {
    throw "Image has transparent pixels, won't convert to JPEG!";
  }

  if (jpegDecodeFailure(file.type, imageData)) {
    throw "JPEG image has transparent pixel, decode failed!";
  }

  return imageData;
}
