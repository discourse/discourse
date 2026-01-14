async function fileToDrawable(file, isIOS) {
  if (!isIOS) {
    return await createImageBitmap(file);
  } else {
    // iOS has performance issues with createImageBitmap on large images
    // this workaround partially borrowed from https://github.com/Donaldcwl/browser-image-compression/blob/master/lib/utils.js
    const dataUrl = URL.createObjectURL(file);
    return await loadImage(dataUrl);
  }
}

function drawableToImageData(drawable, isIOS) {
  const width = drawable.width,
    height = drawable.height,
    sx = 0,
    sy = 0,
    sw = width,
    sh = height;

  let canvas = new OffscreenCanvas(width, height);

  // Check if the canvas is too large
  // iOS _still_ enforces a max pixel count of 16,777,216 per canvas
  const maxLimit = 4096;
  const maximumPixelCount = maxLimit * maxLimit;

  if (isIOS && width * height > maximumPixelCount) {
    const ratio = Math.min(maxLimit / width, maxLimit / height);

    canvas.width = Math.floor(width * ratio);
    canvas.height = Math.floor(height * ratio);
  }

  // Draw image onto canvas
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw "Could not create canvas context";
  }

  ctx.drawImage(drawable, sx, sy, sw, sh, 0, 0, canvas.width, canvas.height);
  const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);

  // iOS strikes again, need to clear canvas to free up memory
  if (isIOS) {
    canvas.width = 1;
    canvas.height = 1;
    ctx && ctx.clearRect(0, 0, 1, 1);
  }

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

export async function fileToImageData(file, isIOS) {
  const drawable = await fileToDrawable(file, isIOS);
  const imageData = drawableToImageData(drawable, isIOS);

  if (isTransparent(file.type, imageData)) {
    throw "Image has transparent pixels, won't convert to JPEG!";
  }

  if (jpegDecodeFailure(file.type, imageData)) {
    throw "JPEG image has transparent pixel, decode failed!";
  }

  return imageData;
}

function loadImage(src) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => {
      URL.revokeObjectURL(src);
      resolve(img);
    };
    img.onerror = (e) => {
      URL.revokeObjectURL(src);
      reject(e);
    };
    img.src = src;
  });
}
