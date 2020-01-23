import User from "discourse/models/user";

let _renderer = defaultRenderTag;

export function replaceTagRenderer(fn) {
  _renderer = fn;
}

function defaultRenderTag(tag, params) {
  params = params || {};
  const visibleName = Handlebars.Utils.escapeExpression(tag);
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
  const href = path ? ` href='${Discourse.getURL(path)}' ` : "";

  if (Discourse.SiteSettings.tag_style || params.style) {
    classes.push(params.style || Discourse.SiteSettings.tag_style);
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
