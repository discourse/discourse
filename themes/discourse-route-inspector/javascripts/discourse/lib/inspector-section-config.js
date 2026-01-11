const SECTION_CONFIG = {
  "current-route": {
    defaultCollapsed: false,
  },
  "route-tree": {
    defaultCollapsed: true,
  },
  "capabilities.viewport": {
    defaultCollapsed: true,
  },
  "capabilities.device": {
    defaultCollapsed: true,
  }
};

export function getSectionConfig(sectionKey) {
  return SECTION_CONFIG[sectionKey] || {};
}

export function getDefaultCollapsed(sectionKey, fallback = false) {
  const { defaultCollapsed } = getSectionConfig(sectionKey);
  if (typeof defaultCollapsed === "boolean") {
    return defaultCollapsed;
  }
  return fallback;
}
