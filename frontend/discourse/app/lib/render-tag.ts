/* eslint-disable prefer-const -- Preserve the original JavaScript emit for this types-only port. */
import escape from "discourse/lib/escape";
import getURL from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import { escapeExpression } from "discourse/lib/utilities";
import User from "discourse/models/user";
import type SiteSettingsService from "discourse/services/site-settings";

/** A tag, by name or as a record. */
export type RenderableTag =
  | string
  | { id?: number | null; name: string; slug?: string | null };

/** Options for rendering a tag. */
export interface RenderTagOptions {
  /** The HTML element. Defaults to `"a"`; any other element has no link. */
  tagName?: string;

  /** Leaves out the link. */
  noHref?: boolean;

  /** Links to the current user's messages with the tag. */
  isPrivateMessage?: boolean;

  /** Links to the current user's messages with the tag. */
  pmOnly?: boolean;

  /** The user whose messages to link to, instead of the current user. */
  tagsForUser?: string | null;

  /** A style class, instead of the `tag_style` site setting. */
  style?: string;

  /** Classes to add. */
  extraClass?: string;

  /** A size class. */
  size?: string;

  /** The text to show instead of the tag name. It is escaped. */
  displayName?: string;

  /** A count to show after the tag. */
  count?: number;

  /** The tag description. The default renderer doesn't show it. */
  description?: string;

  /** Custom renderers can read other options. */
  [key: string]: unknown;
}

/** Renders a tag as HTML. */
export type TagRenderer = (
  tag: RenderableTag,
  params?: RenderTagOptions | null
) => string;

/**
 * TODO(typescript-pending): `SiteSettingsService` does not declare its setting keys, so
 * this types the setting read here. Remove it once the service types its settings.
 */
interface TagSettings {
  tag_style: string;
}

let _renderer: TagRenderer = defaultRenderTag;

/**
 * Replaces the function `renderTag` renders tags with.
 *
 * @param fn - The renderer.
 */
export function replaceTagRenderer(fn: TagRenderer) {
  _renderer = fn;
}

/**
 * Renders a tag as a link to its topic list, or as another element.
 *
 * @param tag - The tag.
 * @param params - The options.
 * @returns The tag HTML.
 */
export function defaultRenderTag(
  tag: RenderableTag,
  params?: RenderTagOptions | null
): string {
  // This file is in lib but it's used as a helper
  let siteSettings = helperContext().siteSettings as SiteSettingsService &
    TagSettings;

  params = params || {};
  const tagName = typeof tag === "string" ? tag : tag.name;
  const visibleName = escapeExpression(tagName);
  const tagNameLower = visibleName.toLowerCase();
  const tagPathName = tagNameLower.replaceAll(".", "%2E");

  const classes = ["discourse-tag"];
  const htmlTag = params.tagName || "a";

  let path: string | undefined;
  if (htmlTag === "a" && !params.noHref) {
    if ((params.isPrivateMessage || params.pmOnly) && User.current()) {
      // The condition above checked that there is a current user.
      const username = params.tagsForUser
        ? params.tagsForUser
        : User.current()!.username;
      path = `/u/${username}/messages/tags/${tagPathName}`;
    } else if (typeof tag === "object" && tag.id) {
      const slugForUrl = tag.slug || `${tag.id}-tag`;
      path = `/tag/${slugForUrl}/${tag.id}`;
    } else {
      path = `/tag/${tagPathName}`;
    }
  }
  const href = path ? ` href='${getURL(path)}' ` : "";

  if (siteSettings.tag_style || params.style) {
    classes.push(params.style || siteSettings.tag_style);
  }
  if (params.extraClass) {
    classes.push(params.extraClass);
  }
  if (params.size) {
    classes.push(params.size);
  }

  let val =
    "<" +
    htmlTag +
    href +
    " data-tag-name=" +
    tagNameLower +
    " class='" +
    classes.join(" ") +
    "'>" +
    (params.displayName ? escape(params.displayName) : visibleName) +
    "</" +
    htmlTag +
    ">";

  if (params.count) {
    val += " <span class='discourse-tag-count'>x" + params.count + "</span>";
  }

  return val;
}

/**
 * Renders a tag with the renderer `replaceTagRenderer` set.
 *
 * @param tag - The tag.
 * @param params - The options.
 * @returns The tag HTML.
 */
export default function renderTag(
  tag: RenderableTag,
  params?: RenderTagOptions | null
): string {
  return _renderer(tag, params);
}
