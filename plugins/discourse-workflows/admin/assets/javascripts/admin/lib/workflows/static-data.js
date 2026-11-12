export function isStaticDataMap(staticData) {
  return (
    staticData &&
    typeof staticData === "object" &&
    !Array.isArray(staticData) &&
    Object.entries(staticData).every(([key, value]) => {
      return (
        key !== "node" &&
        value &&
        typeof value === "object" &&
        !Array.isArray(value)
      );
    })
  );
}

export function mergeImportedStaticData(
  existingStaticData,
  importedStaticData
) {
  const existing = isStaticDataMap(existingStaticData)
    ? existingStaticData
    : {};
  const imported = isStaticDataMap(importedStaticData)
    ? importedStaticData
    : {};
  const merged = {
    ...structuredClone(existing),
    ...structuredClone(imported),
  };

  if (existing.global || imported.global) {
    merged.global = {
      ...(existing.global || {}),
      ...(imported.global || {}),
    };
  }

  return merged;
}
