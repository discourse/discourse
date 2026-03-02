export function interpolationKeysWithStatus(content, keys) {
  if (!keys) {
    return [];
  }

  const knownKeys = new Set(keys);
  const usedKeys = new Set();
  const invalidKeys = new Set();

  if (content) {
    const matches = content.match(/%\{(\w+)\}/g) || [];
    for (const m of matches) {
      const k = m.slice(2, -1);
      if (knownKeys.has(k)) {
        usedKeys.add(k);
      } else {
        invalidKeys.add(k);
      }
    }
  }

  return [
    ...keys.map((key) => ({ key, isUsed: usedKeys.has(key) })),
    ...[...invalidKeys].map((key) => ({ key, isInvalid: true })),
  ];
}
