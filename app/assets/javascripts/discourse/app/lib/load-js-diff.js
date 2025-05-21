/*
Plugins & themes are unable to async-import npm modules directly.
This wrapper provides them with a way to use morphlex, while keeping the `import()` in core's codebase.
*/
export default async function loadJSDiff() {
  return await import("diff");
}
