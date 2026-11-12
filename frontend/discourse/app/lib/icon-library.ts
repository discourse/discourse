import { isDevelopment } from "discourse/lib/environment";
import escape from "discourse/lib/escape";
import { i18n } from "discourse-i18n";

/** Options passed to the icon renderers. Custom renderers may read other keys. */
export interface IconParams {
  /** Classes added to the icon. */
  class?: string | null;

  /** Screen-reader text rendered after the icon by the string renderer. */
  label?: string | null;

  /**
   * The title. The string renderer treats it as a translation key; the element
   * renderer uses it as given.
   */
  title?: string | null;

  /** A title that is already translated, used by the string renderer. */
  translatedTitle?: string | null;

  /** Makes the icon visible to screen readers with this label. */
  "aria-label"?: string | null;

  /**
   * Skips the development-mode missing-icon warning, where the icon is knowingly
   * outside the sprite subset.
   */
  ignoreMissing?: boolean;

  [key: string]: unknown;
}

/** The icon a renderer is asked to render. */
export interface RenderedIcon {
  /** The requested icon id. */
  id: string;

  /** The id that `REPLACEMENTS` maps the requested id to, if any. */
  replacementId: string | undefined;
}

/**
 * Renders icons. Each method returns a falsy value to leave the icon to the next
 * renderer.
 */
export interface IconRenderer {
  /** The renderer's name. */
  name: string;

  /** Renders the icon as an HTML string. */
  string?(icon: RenderedIcon, params: IconParams): string | null | undefined;

  /** Renders the icon as a DOM element. */
  element?(icon: RenderedIcon, params: IconParams): Element | null | undefined;
}

export const SVG_NAMESPACE = "http://www.w3.org/2000/svg";
const _renderers: IconRenderer[] = [];

let _iconList: Set<string> | undefined;

/** Icon ids that render as a different icon. */
export const REPLACEMENTS: Record<string, string> = {
  "d-tracking": "bell",
  "d-muted": "discourse-bell-slash",
  "d-regular": "far-bell",
  "d-watching": "discourse-bell-exclamation",
  "d-watching-first": "discourse-bell-one",
  "d-drop-expanded": "angle-down",
  "d-drop-collapsed": "angle-right",
  "d-unliked": "far-heart",
  "d-liked": "heart",
  "d-post-share": "arrow-up-from-bracket",
  "d-topic-share": "arrow-up-from-bracket",
  "notification.mentioned": "at",
  "notification.group_mentioned": "users",
  "notification.quoted": "quote-right",
  "notification.replied": "reply",
  "notification.posted": "discourse-bell-exclamation",
  "notification.watching_category_or_tag": "discourse-bell-exclamation",
  "notification.edited": "pencil",
  "notification.bookmark_reminder": "discourse-bookmark-clock",
  "notification.liked": "heart",
  "notification.liked_2": "heart",
  "notification.liked_many": "heart",
  "notification.liked_consolidated": "heart",
  "notification.private_message": "envelope",
  "notification.invited_to_private_message": "envelope",
  "notification.invited_to_topic": "hand-point-right",
  "notification.invitee_accepted": "user",
  "notification.moved_post": "right-from-bracket",
  "notification.linked": "link",
  "notification.linked_consolidated": "link",
  "notification.granted_badge": "certificate",
  "notification.topic_reminder": "far-clock",
  "notification.watching_first_post": "discourse-bell-one",
  "notification.group_message_summary": "users",
  "notification.post_approved": "check",
  "notification.membership_request_accepted": "user-plus",
  "notification.membership_request_consolidated": "users",
  "notification.reaction": "bell",
  "notification.votes_released": "plus",
  "notification.chat_quoted": "quote-right",
  "user_menu.replies": "reply",
  "user_menu.drafts": "pencil",
  "sidebar.all_categories": "list",
  "topic.closed": "lock",
  "topic.opened": "unlock",
  "category.restricted": "lock",
};

/**
 * Renders an icon id as a different icon.
 *
 * @param source - The icon id to replace.
 * @param destination - The icon id to render instead.
 */
export function replaceIcon(source: string, destination: string) {
  REPLACEMENTS[source] = destination;
}

/**
 * Renders an icon with the most recently registered renderer that handles it.
 *
 * @param renderType - Whether to render an HTML string or a DOM element.
 * @param id - The icon id.
 * @param params - Options passed to the renderer.
 * @returns The rendered icon, or `undefined` when no renderer handles it.
 */
export function renderIcon(
  renderType: "string",
  id: string,
  params?: IconParams | null
): string | undefined;
export function renderIcon(
  renderType: "element",
  id: string,
  params?: IconParams | null
): Element | undefined;
export function renderIcon(
  renderType: "string" | "element",
  id: string,
  params?: IconParams | null
): string | Element | undefined {
  params ||= {};

  for (const renderer of _renderers) {
    const rendererForType = renderer[renderType];
    if (!rendererForType) {
      continue;
    }

    const icon = { id, replacementId: REPLACEMENTS[id] };
    const result = rendererForType(icon, params);

    if (result) {
      return result;
    }
  }
}

/**
 * Renders an icon as an HTML string.
 *
 * @param id - The icon id.
 * @param params - Options passed to the icon renderer. Set `ignoreMissing` where
 *   the icon is knowingly outside the sprite subset, to skip the development-mode
 *   missing-icon warning.
 * @returns The HTML.
 */
export function iconHTML(id: string, params?: IconParams | null): string {
  // The default renderer below handles every icon.
  return renderIcon("string", id, params) as string;
}

/**
 * Renders an icon as a DOM element.
 *
 * @param id - The icon id.
 * @param params - Options passed to the icon renderer.
 * @returns The element.
 */
export function iconElement(id: string, params?: IconParams | null): Element {
  // The default renderer below handles every icon.
  return renderIcon("element", id, params) as Element;
}

/**
 * Converts an icon class name, such as `"far fa-heart"`, to an icon id.
 *
 * @param icon - The class name.
 * @returns The icon id.
 */
export function convertIconClass(icon: string): string {
  return icon
    .replace("far fa-", "far-")
    .replace("fab fa-", "fab-")
    .replace("fas fa-", "")
    .replace("fa-", "")
    .trim();
}

/**
 * Registers an icon renderer. It runs before every renderer registered earlier.
 *
 * @param renderer - The renderer.
 */
export function registerIconRenderer(renderer: IconRenderer) {
  _renderers.unshift(renderer);
}

function iconClasses(icon: RenderedIcon, params: IconParams) {
  // dots are invalid syntax for classes, use replacement instead
  // (`replacementId` is only set for an existing id)
  const dClass =
    icon.replacementId && icon.id.includes(".") ? icon.replacementId : icon.id;

  let classNames = `fa d-icon d-icon-${dClass} svg-icon fa-width-auto`;

  if (params && params["class"]) {
    classNames += " " + params["class"];
  }

  return classNames;
}

/**
 * Sets the ids of the icons in the SVG sprite subset.
 *
 * @param iconList - The icon ids.
 */
export function setIconList(iconList: Iterable<string>) {
  _iconList = new Set(iconList);
}

/**
 * Whether an icon is in the SVG sprite subset.
 *
 * @param id - The icon id.
 * @returns Whether the icon is in the list, or `undefined` before the list is set.
 */
export function isExistingIconId(id: string): boolean | undefined {
  return _iconList?.has(id);
}

function warnIfMissing(id: string) {
  if (isDevelopment() && !isExistingIconId(id)) {
    console.warn(`The icon "${id}" is missing from the SVG subset.`); // eslint-disable-line no-console
  }
}

function handleIconId(icon: RenderedIcon, params: IconParams) {
  let id = icon.replacementId || icon.id || "";

  // TODO: clean up "thumbtack unpinned" at source instead of here
  id = id.replace(" unpinned", "");

  if (!params.ignoreMissing) {
    warnIfMissing(id);
  }

  return id;
}

// default resolver is font awesome
registerIconRenderer({
  name: "font-awesome",

  string(icon, params) {
    const id = escape(handleIconId(icon, params));
    let html = `<svg class='${escape(iconClasses(icon, params))} svg-string' width='1em' height='1em'`;

    if (params["aria-label"]) {
      html += ` aria-hidden='false' aria-label='${escape(params["aria-label"])}'`;
    } else {
      html += " aria-hidden='true'";
    }
    html += ` xmlns="${SVG_NAMESPACE}"><use href="#${id}" /></svg>`;
    if (params.label) {
      html += `<span class="sr-only">${escape(params.label)}</span>`;
    }
    if (params.title) {
      html = `<span class="svg-icon-title" title="${escape(
        i18n(params.title)
      )}">${html}</span>`;
    }

    if (params.translatedTitle) {
      html = `<span class="svg-icon-title" title="${escape(
        params.translatedTitle
      )}">${html}</span>`;
    }
    return html;
  },

  element(icon, params) {
    const id = escape(handleIconId(icon, params));
    const classes = iconClasses(icon, params) + " svg-node";

    const svgElement = document.createElementNS(SVG_NAMESPACE, "svg");
    svgElement.setAttribute("class", classes);
    svgElement.setAttribute("width", "1em");
    svgElement.setAttribute("height", "1em");
    svgElement.setAttribute("aria-hidden", "true");

    const useElement = document.createElementNS(SVG_NAMESPACE, "use");
    useElement.setAttribute("href", `#${id}`);

    svgElement.appendChild(useElement);

    if (params.title) {
      const spanElement = document.createElement("span");
      spanElement.setAttribute("class", "svg-icon-title");
      spanElement.setAttribute("title", params.title);
      spanElement.appendChild(svgElement);

      return spanElement;
    } else {
      return svgElement;
    }
  },
});
