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
 * @param node - A leaf condition (`{type, ...args}`).
 * @returns The leaf's compact display summary.
 */
export function summarizeLeaf(node: ConditionLeaf | null | undefined): string {
  if (!node?.type) {
    return "";
  }
  const formatter = FORMATTERS[node.type] ?? formatGeneric;
  return formatter(node);
}

/** A formatter for one registered condition leaf shape. */
type ConditionFormatter = (node: ConditionLeaf) => string;

const FORMATTERS: Record<string, ConditionFormatter> = {
  user: formatUser,
  viewport: formatViewport,
  route: formatRoute,
  setting: formatSetting,
  "outlet-arg": formatOutletArg,
};

/**
 * Summarises a user condition.
 *
 * @param node - The user condition leaf.
 * @returns The configured user constraints.
 */
function formatUser(node: ConditionLeaf): string {
  const parts: string[] = [];
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

/**
 * Summarises a viewport condition.
 *
 * @param node - The viewport condition leaf.
 * @returns The configured viewport constraints.
 */
function formatViewport(node: ConditionLeaf): string {
  const parts: string[] = [];
  // TODO(devxp-typescript-pending): `min`/`max` are `unknown` at this boundary;
  // the original runtime uses the raw values (a non-string truthy value is not
  // treated as absent), so cast for `capitalize` rather than narrowing.
  const min = node.min as string;
  const max = node.max as string;
  if (min && max) {
    parts.push(`${capitalize(min)}–${capitalize(max)}`);
  } else if (min) {
    parts.push(`${capitalize(min)} and up`);
  } else if (max) {
    parts.push(`Up to ${capitalize(max)}`);
  }
  if (node.touch === true) {
    parts.push("Touch");
  }
  if (node.touch === false) {
    parts.push("Non-touch");
  }
  return parts.length > 0 ? parts.join(", ") : "Any";
}

/**
 * Summarises a route condition.
 *
 * @param node - The route condition leaf.
 * @returns The configured page or URL constraints.
 */
function formatRoute(node: ConditionLeaf): string {
  if (Array.isArray(node.pages) && node.pages.length > 0) {
    return `Pages: ${node.pages.join(", ")}`;
  }
  if (Array.isArray(node.urls) && node.urls.length > 0) {
    return `URL: ${node.urls.join(", ")}`;
  }
  return "Any";
}

/**
 * Summarises a site-setting condition.
 *
 * @param node - The setting condition leaf.
 * @returns The setting comparison in display form.
 */
function formatSetting(node: ConditionLeaf): string {
  // TODO(devxp-typescript-pending): `name` is `unknown` at this boundary; the
  // original runtime uses the raw value (a non-string truthy value is not
  // treated as absent), so cast rather than narrowing.
  const name = node.name as string;
  if (!name) {
    return "(unset)";
  }
  if (node.enabled === true) {
    return `${name} enabled`;
  }
  if (node.enabled === false) {
    return `${name} disabled`;
  }
  if (node.equals !== undefined) {
    return `${name} = ${JSON.stringify(node.equals)}`;
  }
  if (Array.isArray(node.includes)) {
    return `${name} includes ${node.includes.join(", ")}`;
  }
  return name;
}

/**
 * Summarises an outlet-argument condition.
 *
 * @param node - The outlet-argument condition leaf.
 * @returns The configured path and optional comparison value.
 */
function formatOutletArg(node: ConditionLeaf): string {
  // TODO(devxp-typescript-pending): `path` is `unknown` at this boundary; the
  // original runtime uses the raw value (a non-string truthy value is not
  // treated as absent), so cast rather than narrowing.
  const path = node.path as string;
  if (!path) {
    return "(unset)";
  }
  if (node.value !== undefined) {
    return `${path} = ${JSON.stringify(node.value)}`;
  }
  return path;
}

/**
 * Summarises an unrecognised condition using its argument entries.
 *
 * @param node - The condition leaf to summarise.
 * @returns A comma-separated argument list.
 */
function formatGeneric(node: ConditionLeaf): string {
  const parts: string[] = [];
  for (const [key, value] of Object.entries(node)) {
    if (key === "type") {
      continue;
    }
    parts.push(`${key}=${JSON.stringify(value)}`);
  }
  return parts.length > 0 ? parts.join(", ") : "Any";
}

/**
 * Uppercases the first character of a display label.
 *
 * @param value - The label to capitalise.
 * @returns The label with an uppercase first character.
 */
function capitalize(value: string): string {
  return value.charAt(0).toUpperCase() + value.slice(1);
}
import type { ConditionLeaf } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";
