import { modifier } from "ember-modifier";

const ATKINSON_NEIGHBORS = [
  [1, 0],
  [2, 0],
  [-1, 1],
  [0, 1],
  [1, 1],
  [0, 2],
];

function renderDitheredImage(image, width) {
  const height = Math.max(
    1,
    Math.round((width * image.naturalHeight) / image.naturalWidth)
  );
  const canvas = image.ownerDocument.createElement("canvas");
  canvas.width = width;
  canvas.height = height;

  const context = canvas.getContext("2d");
  if (!context) {
    return;
  }

  context.imageSmoothingQuality = "high";
  context.fillStyle = "#fff";
  context.fillRect(0, 0, width, height);
  context.drawImage(image, 0, 0, width, height);

  let pixels;
  try {
    pixels = context.getImageData(0, 0, width, height);
  } catch (error) {
    if (error.name === "SecurityError") {
      return;
    }
    throw error;
  }

  const luminance = new Float32Array(width * height);
  const { data } = pixels;
  for (let index = 0; index < luminance.length; index++) {
    const offset = index * 4;
    luminance[index] =
      0.2126 * data[offset] +
      0.7152 * data[offset + 1] +
      0.0722 * data[offset + 2];
  }

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const index = y * width + x;
      const color = luminance[index] < 128 ? 0 : 255;
      const error = (luminance[index] - color) / 8;
      const offset = index * 4;
      data[offset] = color;
      data[offset + 1] = color;
      data[offset + 2] = color;

      for (const [dx, dy] of ATKINSON_NEIGHBORS) {
        const nextX = x + dx;
        const nextY = y + dy;
        if (nextX >= 0 && nextX < width && nextY < height) {
          luminance[nextY * width + nextX] += error;
        }
      }
    }
  }

  context.putImageData(pixels, 0, 0);
  canvas.setAttribute("aria-hidden", "true");
  canvas.title = image.title;
  return canvas;
}

export default modifier((frame) => {
  const image = frame.querySelector("img");
  if (!image) {
    return;
  }

  const visibility = image.style.visibility;
  let canvas;
  let animationFrame;
  let sampledWidth;
  const draw = () => {
    const width = Math.floor(image.clientWidth / 2);
    if (
      !image.complete ||
      !image.naturalWidth ||
      !width ||
      width === sampledWidth
    ) {
      return;
    }

    sampledWidth = width;
    const ditheredImage = renderDitheredImage(image, width);
    if (!ditheredImage) {
      return;
    }

    if (canvas) {
      canvas.replaceWith(ditheredImage);
    } else {
      image.after(ditheredImage);
      image.style.visibility = "hidden";
    }
    canvas = ditheredImage;
  };

  image.addEventListener("load", draw);
  const observer = new ResizeObserver(() => {
    cancelAnimationFrame(animationFrame);
    animationFrame = requestAnimationFrame(draw);
  });
  observer.observe(image);
  draw();

  return () => {
    image.removeEventListener("load", draw);
    observer.disconnect();
    cancelAnimationFrame(animationFrame);
    canvas?.remove();
    image.style.visibility = visibility;
  };
});
