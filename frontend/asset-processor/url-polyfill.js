export function pathToFileURL(path) {
  return new URL(path, "file://").toString();
}

export function fileURLToPath(url) {
  return new URL(url).pathname;
}
