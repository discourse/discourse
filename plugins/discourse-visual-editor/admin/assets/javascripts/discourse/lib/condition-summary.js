// @ts-check

/**
 * Generates a short human-readable summary string for a leaf condition,
 * used as the visible label of a `<ConditionPill>` in the inspector.
 *
 * The summary is rendered AFTER the type's `displayName`, so the full
 * chip reads as `"User: Admin"` / `"Viewport: Desktop and up"` etc.
 *
 * Each per-type formatter falls back to a comma-joined list of
 * `key=value` pairs when no specific shape matches, so the chip stays
 * readable even for conditions we haven't pattern-matched.
 *
 * @param {Object} node - A leaf condition (`{type, ...args}`).
 * @returns {string}
 */
export function summarizeLeaf(node) {
  if (!node?.type) {
    return "";
  }
  const formatter = FORMATTERS[node.type] ?? formatGeneric;
  return formatter(node);
}

const FORMATTERS = {
  user: formatUser,
  viewport: formatViewport,
  route: formatRoute,
  setting: formatSetting,
  "outlet-arg": formatOutletArg,
};

function formatUser(node) {
  const parts = [];
  if (node.admin === true) {
    parts.push("Admin");
  }
  if (node.moderator === true) {
    parts.push("Moderator");
  }
  if (node.staff === true && !node.admin && !node.moderator) {
    parts.push("Staff");
  }
  if (node.loggedIn === true) {
    parts.push("Logged in");
  }
  if (node.loggedIn === false) {
    parts.push("Anonymous");
  }
  if (node.minTrustLevel != null && node.maxTrustLevel != null) {
    parts.push(`TL${node.minTrustLevel}–TL${node.maxTrustLevel}`);
  } else if (node.minTrustLevel != null) {
    parts.push(`TL${node.minTrustLevel}+`);
  } else if (node.maxTrustLevel != null) {
    parts.push(`≤ TL${node.maxTrustLevel}`);
  }
  if (Array.isArray(node.groups) && node.groups.length > 0) {
    parts.push(`Groups: ${node.groups.join(", ")}`);
  }
  return parts.length > 0 ? parts.join(", ") : "Any";
}

function formatViewport(node) {
  const parts = [];
  if (node.min && node.max) {
    parts.push(`${capitalize(node.min)}–${capitalize(node.max)}`);
  } else if (node.min) {
    parts.push(`${capitalize(node.min)} and up`);
  } else if (node.max) {
    parts.push(`Up to ${capitalize(node.max)}`);
  }
  if (node.touch === true) {
    parts.push("Touch");
  }
  if (node.touch === false) {
    parts.push("Non-touch");
  }
  return parts.length > 0 ? parts.join(", ") : "Any";
}

function formatRoute(node) {
  if (Array.isArray(node.pages) && node.pages.length > 0) {
    return `Pages: ${node.pages.join(", ")}`;
  }
  if (Array.isArray(node.urls) && node.urls.length > 0) {
    return `URL: ${node.urls.join(", ")}`;
  }
  return "Any";
}

function formatSetting(node) {
  if (!node.name) {
    return "(unset)";
  }
  if (node.enabled === true) {
    return `${node.name} enabled`;
  }
  if (node.enabled === false) {
    return `${node.name} disabled`;
  }
  if (node.equals !== undefined) {
    return `${node.name} = ${JSON.stringify(node.equals)}`;
  }
  if (Array.isArray(node.includes)) {
    return `${node.name} includes ${node.includes.join(", ")}`;
  }
  return node.name;
}

function formatOutletArg(node) {
  if (!node.path) {
    return "(unset)";
  }
  if (node.value !== undefined) {
    return `${node.path} = ${JSON.stringify(node.value)}`;
  }
  return node.path;
}

function formatGeneric(node) {
  const parts = [];
  for (const [key, value] of Object.entries(node)) {
    if (key === "type") {
      continue;
    }
    parts.push(`${key}=${JSON.stringify(value)}`);
  }
  return parts.length > 0 ? parts.join(", ") : "Any";
}

function capitalize(s) {
  return s.charAt(0).toUpperCase() + s.slice(1);
}
