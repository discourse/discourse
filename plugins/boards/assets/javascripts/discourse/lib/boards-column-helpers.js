import { trustHTML } from "@ember/template";
import { isValidHex, normalizeHex } from "discourse/lib/color-transformations";
import { i18n } from "discourse-i18n";

export const COLUMN_SORT_OPTIONS = [
  {
    id: "priority",
    name: i18n("boards.manage.columns.default_sort_priority"),
  },
  {
    id: "recency",
    name: i18n("boards.manage.columns.default_sort_recency"),
  },
];

export const STATUS_OPTIONS = [
  {
    id: "open",
    name: i18n("boards.manage.columns.move_to_status_open"),
  },
  {
    id: "closed",
    name: i18n("boards.manage.columns.move_to_status_closed"),
  },
];

// Suggested palette fed to the FormKit color control as @colors. Values are
// bare 6-digit hexes (no leading "#"), matching how core stores category colors.
// The control also accepts any custom hex.
export const PRESET_COLUMN_COLORS = [
  "C97CF4",
  "FCA700",
  "669DF1",
  "F87168",
  "94C748",
  "4BCE97",
  "E774BB",
  "DDB30E",
  "6CC3E0",
];

// True when a stored color is a usable hex; drives the discourse-boards-column--has-color modifier.
export function hasColumnColor(color) {
  return !!isValidHex(color);
}

// Relative luminance of a 6-digit hex (0–1), used to pick contrasting text.
function luminance(hex) {
  const r = parseInt(hex.slice(0, 2), 16);
  const g = parseInt(hex.slice(2, 4), 16);
  const b = parseInt(hex.slice(4, 6), 16);
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
}

// Mirrors core's categoryColorVariable: turns a stored hex into inline custom
// properties — the fill plus a contrasting title text color so the header
// stays readable for any color, preset or custom. The title sits on a chip
// that darkens the fill by ~30%, so its text color is judged against that
// darker background. The header text (count included) stays a tint of the
// fill's own hue, with its lightness handled scheme-side in SCSS.
export function columnColorVariable(color) {
  if (!isValidHex(color)) {
    // Colorless columns fill with the scheme's --primary-500; --secondary is
    // core's text-on-filled-control color and tracks scheme switches live,
    // so no contrast math is needed here.
    return trustHTML(
      "--discourse-boards-column-color: var(--primary-500); --discourse-boards-column-title-text-color: var(--secondary);"
    );
  }
  const hex = normalizeHex(color);
  const lum = luminance(hex);
  const titleText = lum * 0.7 > 0.5 ? "#000000" : "#ffffff";
  return trustHTML(
    `--discourse-boards-column-color: #${hex}; --discourse-boards-column-title-text-color: ${titleText};`
  );
}

export const ASSIGNED_OPTIONS = [
  {
    id: "nobody",
    name: i18n("boards.manage.columns.move_to_assigned_unassign"),
  },
  {
    id: "_user",
    name: i18n("boards.manage.columns.move_to_assigned_user"),
  },
];

export function tagToArray(tag) {
  return tag ? [tag] : [];
}

export function assignedMode(value) {
  if (!value) {
    return "";
  }
  if (value === "nobody") {
    return "nobody";
  }
  return "_user";
}

export function assignedUserValue(value) {
  if (!value || value === "nobody" || value === "_user") {
    return [];
  }
  return [value];
}
