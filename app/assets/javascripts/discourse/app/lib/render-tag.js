import User from "discourse/models/user";
import { escapeExpression } from "discourse/lib/utilities";
import getURL from "discourse-common/lib/get-url";
import { helperContext } from "discourse-common/lib/helpers";

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
  if (params.size) {
    classes.push(params.size);
  }

  let val =
    "<" +
    tagName +
    href +
    " data-tag-name=" +
    tag +
    (params.description ? ' title="' + params.description + '" ' : "") +
    " class='" +
    classes.join(" ") +
    "'>" +
    visibleName +
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
