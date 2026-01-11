export function computeLong(data, threshold = 3) {
  if (!data || typeof data !== "object") {
    return false;
  }
  return Object.keys(data).length > threshold;
}
