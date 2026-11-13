export default function hasTranslatableFields(schema) {
  return Object.values(schema?.properties ?? {}).some(
    (spec) =>
      spec.translatable === true ||
      (spec.type === "objects" && hasTranslatableFields(spec.schema))
  );
}
