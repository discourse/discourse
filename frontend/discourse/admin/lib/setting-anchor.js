export function settingAnchorId(name) {
  return `setting-${name}`;
}

export function settingNameFromFragment(fragment) {
  if (!fragment) {
    return null;
  }

  try {
    const decoded = decodeURIComponent(fragment.replace(/^#/, ""));
    return decoded.startsWith("setting-")
      ? decoded.slice("setting-".length)
      : null;
  } catch {
    return null;
  }
}
