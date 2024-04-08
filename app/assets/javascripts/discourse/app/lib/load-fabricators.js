let fabricators;

/*
Plugins & themes are unable to async-import directly.
This wrapper provides them with a way to use fakerjs, while keeping the `import()` in core's codebase.
*/
export async function loadFabricators() {
  fabricators = await import("discourse/static/lib/fabricators");
  return fabricators;
}

/**
 * Return fabricator syncronously. If loadFabricator was not completed first, will return null.
 */
export function getFabricators() {
  return fabricators;
}
