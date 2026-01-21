import { normalizeHex } from "discourse/lib/color-transformations";

export default function hexToRGBA(hexCode, opacity) {
  const hex = normalizeHex(hexCode);

  const r = parseInt(hex.substring(0, 2), 16);
  const g = parseInt(hex.substring(2, 4), 16);
  const b = parseInt(hex.substring(4, 6), 16);

  return `rgba(${r},${g},${b}, ${opacity})`;
}
