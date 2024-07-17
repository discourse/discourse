import { escapeExpression } from "discourse/lib/utilities";
import User from "discourse/models/user";
import escape from "discourse-common/lib/escape";
import getURL from "discourse-common/lib/get-url";
import { helperContext } from "discourse-common/lib/helpers";

let _renderer = defaultRenderTag;

export function replaceTagRenderer(fn) {
  _renderer = fn;
}

function buildTagHTML(tagName, attrs, innerHTML) {
  let val = `<${tagName}`;
  for (const [k, v] of Object.entries(attrs)) {
    val += v ? ` ${k}="${escape(v)}"` : "";
  }
  val += `>${innerHTML}</${tagName}>`;
  return val;
}

/**
 * @param {Object} extra Reserved for theme components and plugins so they don't have to rewrite the entire renderer
 * @param {Record<string, string>?} extra.attrs Add or override tag attributes
 * @param {((content: string)=>string)?} extra.contentFn Override the innerHTML of a tag
 * @param {string?} extra.extraClass Adding additional classes to tags
 */
export function defaultRenderTag(tag, params, extra) {
  // This file is in lib but it's used as a helper
  let siteSettings = helperContext().siteSettings;

  params = params || {};
  extra = extra || {};

  const visibleName = escapeExpression(tag);
  tag = visibleName.toLowerCase();
  const classes = ["discourse-tag"];
  const tagName = params.tagName || "a";
  let path;
  if (tagName === "a" && !params.noHref) {
    if ((params.isPrivateMessage || params.pmOnly) && User.current()) {
      const username = params.tagsForUser
        ? params.tagsForUser
        : User.current().username;
      path = `/u/${username}/messages/tags/${tag}`;
    } else {
      path = `/tag/${tag}`;
    }
  }

  if (siteSettings.tag_style || params.style) {
    classes.push(params.style || siteSettings.tag_style);
  }
  if (params.extraClass) {
    classes.push(params.extraClass);
  }
  if (extra.extraClass) {
    classes.push(extra.extraClass);
  }
  if (params.size) {
    classes.push(params.size);
  }

  // remove all html tags from hover text
  const hoverDescription = params.description?.replace(/<.+?>/g, "");

  const content = params.displayName ? escape(params.displayName) : visibleName;

  let val = buildTagHTML(
    tagName,
    {
      href: path && getURL(path),
      "data-tag-name": tag,
      "data-tag-groups": params.tagGroup || params.tagGroups?.join(","),
      title: hoverDescription,
      class: classes.join(" "),
      ...(extra.attrs ?? {}),
    },
    extra.contentFn?.(content) ?? content
  );

  if (params.count) {
    val += " <span class='discourse-tag-count'>x" + params.count + "</span>";
  }

  return val;
}

export default function renderTag(tag, params) {
  return _renderer(tag, params);
}
