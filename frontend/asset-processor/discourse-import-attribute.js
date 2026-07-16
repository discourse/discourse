// Reads and validates the `with { discourseImport: ... }` attribute on an
// import declaration, returning "optional", "required", or undefined.
export function readDiscourseImportMode(path) {
  const attribute = (path.node.attributes ?? []).find(
    (a) => (a.key.name ?? a.key.value) === "discourseImport"
  );
  const mode = attribute?.value.value;
  if (![undefined, "optional", "required"].includes(mode)) {
    throw path.buildCodeFrameError(
      `Invalid \`discourseImport\` import attribute "${mode}". Allowed values are "optional" and "required".`
    );
  }
  return mode;
}
