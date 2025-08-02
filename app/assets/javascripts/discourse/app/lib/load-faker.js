let faker;

/*
Plugins & themes are unable to async-import npm modules directly.
This wrapper provides them with a way to use fakerjs, while keeping the `import()` in core's codebase.
*/
export default async function loadFaker() {
  faker ??= await import("@faker-js/faker");
  return faker;
}

export function setLoadedFaker(module) {
  faker = module;
}

export function getLoadedFaker() {
  if (!faker) {
    throw "Faker has not been loaded yet. Ensure `setLoadedFaker()` or `loadFaker()` have been called first";
  }
  return faker;
}
