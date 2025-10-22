import { h } from "virtual-dom";
import attributeHook from "discourse/lib/attribute-hook";
import deprecated from "discourse/lib/deprecated";
import { isDevelopment } from "discourse/lib/environment";
import escape from "discourse/lib/escape";
import { i18n } from "discourse-i18n";

export const SVG_NAMESPACE = "http://www.w3.org/2000/svg";
let _renderers = [];

let warnMissingIcons = true;
let _iconList;

export const REPLACEMENTS = {
  "d-tracking": "bell",
  "d-muted": "discourse-bell-slash",
  "d-regular": "far-bell",
  "d-watching": "discourse-bell-exclamation",
  "d-watching-first": "discourse-bell-one",
  "d-drop-expanded": "caret-down",
  "d-drop-collapsed": "caret-right",
  "d-unliked": "far-heart",
  "d-liked": "heart",
  "d-post-share": "link",
  "d-topic-share": "link",
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

export function replaceIcon(source, destination) {
  REPLACEMENTS[source] = destination;
}

export function disableMissingIconWarning() {
  warnMissingIcons = false;
}

export function enableMissingIconWarning() {
  warnMissingIcons = false;
}

export function renderIcon(renderType, id, params) {
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

export function iconHTML(id, params) {
  return renderIcon("string", id, params);
}

export function iconNode(id, params) {
  return renderIcon("node", id, params);
}

export function convertIconClass(icon) {
  return icon
    .replace("far fa-", "far-")
    .replace("fab fa-", "fab-")
    .replace("fas fa-", "")
    .replace("fa-", "")
    .trim();
}

export function registerIconRenderer(renderer) {
  _renderers.unshift(renderer);
}

function iconClasses(icon, params) {
  // "notification." is invalid syntax for classes, use replacement instead
  const dClass =
    icon.replacementId && icon.id.includes("notification.")
      ? icon.replacementId
      : icon.id;

  let classNames = `fa d-icon d-icon-${dClass} svg-icon`;

  if (params && params["class"]) {
    classNames += " " + params["class"];
  }

  return classNames;
}

export function setIconList(iconList) {
  _iconList = iconList;
}

export function isExistingIconId(id) {
  return _iconList?.includes(id);
}

function warnIfMissing(id) {
  if (warnMissingIcons && isDevelopment() && !isExistingIconId(id)) {
    console.warn(`The icon "${id}" is missing from the SVG subset.`); // eslint-disable-line no-console
  }
}

function handleIconId(icon) {
  let id = icon.replacementId || icon.id || "";

  // TODO: clean up "thumbtack unpinned" at source instead of here
  id = id.replace(" unpinned", "");

  warnIfMissing(id);
  return id;
}

// default resolver is font awesome
registerIconRenderer({
  name: "font-awesome",

  string(icon, params) {
    const id = escape(handleIconId(icon));
    let html = `<svg class='${escape(iconClasses(icon, params))} svg-string'`;

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

    if (params.translatedtitle) {
      deprecated(`use 'translatedTitle' option instead of 'translatedtitle'`, {
        since: "2.9.0.beta6",
        dropFrom: "2.10.0.beta1",
        id: "discourse.icon-renderer-translatedtitle",
      });
      params.translatedTitle = params.translatedtitle;
    }

    if (params.translatedTitle) {
      html = `<span class="svg-icon-title" title="${escape(
        params.translatedTitle
      )}">${html}</span>`;
    }
    return html;
  },

  node(icon, params) {
    const id = handleIconId(icon);
    const classes = iconClasses(icon, params) + " svg-node";

    const svg = h(
      "svg",
      {
        attributes: { class: classes, "aria-hidden": true },
        namespace: SVG_NAMESPACE,
      },
      [
        h("use", {
          href: attributeHook("http://www.w3.org/1999/xlink", `#${escape(id)}`),
          namespace: SVG_NAMESPACE,
        }),
      ]
    );

    if (params.title) {
      return h(
        "span",
        {
          title: params.title,
          attributes: { class: "svg-icon-title" },
        },
        [svg]
      );
    } else {
      return svg;
    }
  },
});
