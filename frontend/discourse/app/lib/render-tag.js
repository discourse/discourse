import escape from "discourse/lib/escape";
import getURL from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import { escapeExpression } from "discourse/lib/utilities";
import User from "discourse/models/user";

let _renderer = defaultRenderTag;

export function replaceTagRenderer(fn) {
  _renderer = fn;
}

export function defaultRenderTag(tag, params) {
  // This file is in lib but it's used as a helper
  let siteSettings = helperContext().siteSettings;

  params = params || {};
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

  // remove all html tags from hover text
  const hoverDescription =
    params.description && params.description.replace(/<.+?>/g, "");

  let val =
    "<" +
    tagName +
    href +
    " data-tag-name=" +
    tag +
    (params.description ? ' title="' + escape(hoverDescription) + '" ' : "") +
    " class='" +
    classes.join(" ") +
    "'>" +
    (params.displayName ? escape(params.displayName) : visibleName) +
    "</" +
    tagName +
    ">";

  if (params.count) {
    val += " <span class='discourse-tag-count'>x" + params.count + "</span>";
  }

  return val;
}

export default function renderTag(tag, params) {
  return _renderer(tag, params);
}
