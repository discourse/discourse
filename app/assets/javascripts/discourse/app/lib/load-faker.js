/*
Plugins & themes are unable to async-import npm modules directly.
This wrapper provides them with a way to use fakerjs, while keeping the `import()` in core's codebase.
*/
export default async function loadFaker() {
  return await import("@faker-js/faker");
}
