// This file's code is based on Favcount by Chris Hunt, Copyright 2013 Chris Hunt, MIT License

function renderIcon(canvas, img, count) {
  count = Math.round(count);
  if (isNaN(count) || count < 1) {
    count = "";
  } else if (count < 10) {
    count = " " + count;
  } else if (count > 99) {
    count = "99";
  }

  // Scale canvas elements based on favicon size
  let multiplier = img.width / 16;
  let fontSize = multiplier * 11;
  let xOffset = multiplier;
  let shadow = multiplier * 2;

  canvas.height = canvas.width = img.width;
  let ctx = canvas.getContext("2d");
  ctx.font = `bold ${fontSize}px Arial, sans-serif`;

  if (count) {
    ctx.globalAlpha = 0.4;
  }
  ctx.drawImage(img, 0, 0);
  ctx.globalAlpha = 1.0;

  // Draw white drop shadow
  ctx.shadowColor = "#FFF";
  ctx.shadowBlur = shadow;
  ctx.shadowOffsetX = 0;
  ctx.shadowOffsetY = 0;

  // Draw white border
  ctx.fillStyle = "#FFF";
  ctx.fillText(count, xOffset, fontSize);
  ctx.fillText(count, xOffset + multiplier, fontSize);
  ctx.fillText(count, xOffset, fontSize + multiplier);
  ctx.fillText(count, xOffset + multiplier, fontSize + multiplier);

  // Draw black count
  ctx.fillStyle = "#000";
  ctx.fillText(count, xOffset + multiplier / 2.0, fontSize + multiplier / 2.0);

  // Replace favicon with new favicon
  let newFavicon = document.createElement("link");
  newFavicon.rel = "icon";
  newFavicon.href = canvas.toDataURL("image/png");
  let favicon = document.querySelector("link[rel=icon]");

  let head = document.querySelector("head");
  if (favicon) {
    head.removeChild(favicon);
  }
  head.appendChild(newFavicon);
}

export default function tabCount(url, count) {
  let canvas = document.createElement("canvas");
  if (canvas.getContext) {
    let img = document.createElement("img");
    img.crossOrigin = "anonymous";
    img.onload = () => renderIcon(canvas, img, count);
    img.src = url;
  }
}
