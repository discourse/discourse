// https://stackoverflow.com/a/16348977
export function stringToColor(str) {
  let hash = 0;
  for (let i = 0; i < str.length; i++) {
    // eslint-disable-next-line no-bitwise
    hash = str.charCodeAt(i) + ((hash << 5) - hash);
  }
  let color = [];
  for (let i = 0; i < 3; i++) {
    // eslint-disable-next-line no-bitwise
    let value = (hash >> (i * 8)) & 0xff;
    color.push(value);
  }
  return color;
}

export function colorToHex(color) {
  let hex = "#";
  for (let i = 0; i < 3; i++) {
    hex += ("00" + Math.round(color[i]).toString(16)).slice(-2);
  }
  return hex;
}

export function contrastColor(color) {
  const luminance = 0.2126 * color[0] + 0.7152 * color[1] + 0.0722 * color[2];
  return luminance / 255 >= 0.5 ? "#000d" : "#fffd";
}
