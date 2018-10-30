import { h } from "virtual-dom";
import attributeHook from "discourse/lib/attribute-hook";
import deprecated from "discourse-common/lib/deprecated";

const SVG_NAMESPACE = "http://www.w3.org/2000/svg";
let _renderers = [];

const REPLACEMENTS = {
  "d-tracking": "circle",
  "d-muted": "times-circle",
  "d-regular": "circle-o",
  "d-watching": "exclamation-circle",
  "d-watching-first": "dot-circle-o",
  "d-drop-expanded": "caret-down",
  "d-drop-collapsed": "caret-right",
  "d-unliked": "far-heart",
  "d-liked": "heart",
  "notification.mentioned": "at",
  "notification.group_mentioned": "at",
  "notification.quoted": "quote-right",
  "notification.replied": "reply",
  "notification.posted": "reply",
  "notification.edited": "pencil-alt",
  "notification.liked": "heart",
  "notification.liked_2": "heart",
  "notification.liked_many": "heart",
  "notification.private_message": "far-envelope",
  "notification.invited_to_private_message": "far-envelope",
  "notification.invited_to_topic": "far-hand-point-right",
  "notification.invitee_accepted": "user",
  "notification.moved_post": "sign-out",
  "notification.linked": "link",
  "notification.granted_badge": "certificate",
  "notification.topic_reminder": "hand-o-right",
  "notification.watching_first_post": "dot-circle-o",
  "notification.group_message_summary": "group"
};

const fa4Replacements = {
  "area-chart": "chart-area",
  "bar-chart": "far-chart-bar",
  "bar-chart-o": "far-chart-bar",
  "chain-broken": "unlink",
  "circle-thin": "far-circle",
  "code-fork": "code-branch",
  "commenting-o": "far-comment-dots",
  "credit-card": "far-credit-card",
  "drivers-license": "id-card",
  "drivers-license-o": "far-id-card",
  "external-link": "external-link-alt",
  "external-link-square": "external-link-square-alt",
  "eye-slash": "far-eye-slash",
  "facebook-square": "fab-facebook-square",
  "file-sound-o": "far-file-audio",
  "file-text": "file-alt",
  "file-text-o": "far-file-alt",
  "files-o": "far-copy",
  "floppy-o": "far-save",
  "github-alt": "fab-github-alt",
  "github-square": "fab-github-square",
  "hacker-news": "fab-hacker-news",
  "hand-grab-o": "far-hand-rock",
  "id-badge": "far-id-badge",
  "internet-explorer": "fab-internet-explorer",
  "line-chart": "chart-line",
  "linkedin-square": "fab-linkedin",
  "list-alt": "far-list-alt",
  "mail-forward": "share",
  "mail-reply": "reply",
  "mail-reply-all": "reply-all",
  "map-marker": "map-marker-alt",
  "mobile-phone": "mobile-alt",
  "object-group": "far-object-group",
  "object-ungroup": "far-object-ungroup",
  "pencil-square": "pen-square",
  "pencil-square-o": "far-edit",
  "picture-o": "far-image",
  "pie-chart": "chart-pie",
  "rotate-left": "undo",
  "rotate-right": "redo",
  "send-o": "far-paper-plane",
  "sign-in": "sign-in-alt",
  "sign-out": "sign-out-alt",
  "soccer-ball-o": "far-futbol",
  "sort-alpha-asc": "sort-alpha-down",
  "sort-alpha-desc": "sort-alpha-up",
  "sort-amount-asc": "sort-amount-down",
  "sort-amount-desc": "sort-amount-up",
  "sort-asc": "sort-up",
  "sort-desc": "sort-down",
  "sort-numeric-asc": "sort-numeric-down",
  "sort-numeric-desc": "sort-numeric-up",
  "star-half-empty": "far-star-half",
  "star-half-full": "far-star-half",
  "thumb-tack": "thumbtack",
  "times-rectangle": "window-close",
  "times-rectangle-o": "far-window-close",
  "toggle-down": "far-caret-square-down",
  "toggle-left": "far-caret-square-left",
  "toggle-right": "far-caret-square-right",
  "toggle-up": "far-caret-square-up",
  "trash-o": "far-trash-alt",
  "twitter-square": "fab-twitter-square",
  "vcard-o": "far-address-card",
  "video-camera": "video",
  "vimeo-square": "fab-vimeo-square",
  "wheelchair-alt": "fab-accessible-icon",
  "window-maximize": "far-window-maximize",
  "window-restore": "far-window-restore",
  "youtube-play": "fab-youtube",
  "youtube-square": "fab-youtube-square",
  apple: "fab-apple",
  bank: "university",
  cab: "taxi",
  calendar: "calendar-alt",
  chain: "link",
  clipboard: "far-clipboard",
  clone: "far-clone",
  close: "times",
  cny: "yen-sign",
  commenting: "far-comment-dots",
  compass: "far-compass",
  copyright: "far-copyright",
  cutlery: "utensils",
  dashboard: "tachometer-alt",
  deafness: "deaf",
  dedent: "outdent",
  diamond: "far-gem",
  dollar: "dollar-sign",
  exchange: "exchange-alt",
  eye: "far-eye",
  eyedropper: "eye-dropper",
  facebook: "fab-facebook-f",
  feed: "rss",
  flash: "bolt",
  gbp: "pound-sign",
  gear: "cog",
  gears: "cogs",
  github: "fab-github",
  glass: "glass-martini",
  glass: "glass-martini",
  google: "fab-google",
  group: "users",
  header: "heading",
  hotel: "bed",
  ils: "shekel-sign",
  image: "far-image",
  inr: "rupee-sign",
  instagram: "fab-instagram",
  institution: "university",
  intersex: "transgender",
  jpy: "yen-sign",
  legal: "gavel",
  linkedin: "fab-linkedin-in",
  linode: "fab-linode",
  linux: "fab-linux",
  meetup: "fab-meetup",
  mobile: "mobile-alt",
  navicon: "bars",
  paste: "far-clipboard",
  pencil: "pencil-alt",
  photo: "far-image",
  refresh: "sync",
  registered: "far-registered",
  remove: "times",
  remove: "times",
  reorder: "bars",
  repeat: "redo",
  rmb: "yen-sign",
  rouble: "ruble-sign",
  ruble: "ruble-sign",
  rupee: "rupee-sign",
  s15: "bath",
  scissors: "cut",
  send: "paper-plane",
  shekel: "shekel-sign",
  shield: "shield-alt",
  signing: "sign-language",
  support: "far-life-ring",
  tablet: "tablet-alt",
  tachometer: "tachometer-alt",
  television: "tv",
  ticket: "ticket-alt",
  trash: "trash-alt",
  twitter: "fab-twitter",
  unsorted: "sort",
  vcard: "address-card",
  vimeo: "fab-vimeo-v",
  warning: "exclamation-triangle",
  whatsapp: "fab-whatsapp",
  windows: "fab-windows",
  youtube: "fab-youtube"
};

export function replaceIcon(source, destination) {
  REPLACEMENTS[source] = destination;
}

export function renderIcon(renderType, id, params) {
  for (let i = 0; i < _renderers.length; i++) {
    let renderer = _renderers[i];
    let rendererForType = renderer[renderType];

    if (rendererForType) {
      const icon = { id, replacementId: REPLACEMENTS[id] };
      let result = rendererForType(icon, params || {});
      if (result) {
        return result;
      }
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
  icon = icon.replace("far fa-", "far-");
  icon = icon.replace("fab fa-", "fab-");
  icon = icon.replace("fa-", "");
  return icon;
}

// TODO: Improve how helpers are registered for vdom compliation
if (typeof Discourse !== "undefined") {
  Discourse.__widget_helpers.iconNode = iconNode;
}

export function registerIconRenderer(renderer) {
  _renderers.unshift(renderer);
}

function iconClasses(icon, params) {
  let classNames = `fa d-icon d-icon-${icon.id} svg-icon`;

  if (params && params["class"]) {
    classNames += " " + params["class"];
  }

  return classNames;
}

function warnIfMissing(id) {
  if (Discourse.SvgIconList.indexOf(id) === -1) {
    console.warn(`The icon "${id}" is missing from the SVG subset.`);
  }
}

function handleIconId(icon) {
  let id = icon.replacementId || icon.id || "";

  if (fa4Replacements.hasOwnProperty(id)) {
    deprecated(
      `Icon "${id}" is now "${fa4Replacements[id]}" in Font Awesome 5.`
    );
    id = fa4Replacements[id];
  } else if (id.substr(id.length - 2) === "-o") {
    let new_id = "far-" + id.replace("-o", "");
    deprecated(`Icon "${id}" is now "${new_id}" in Font Awesome 5.`);
    id = new_id;
  }

  // TODO: the "unpinned thumbtack" icon should be replaced, but currently it's used in too many places
  id = id.replace(" unpinned", "");

  warnIfMissing(id);
  return id;
}

// default resolver is font awesome
registerIconRenderer({
  name: "font-awesome",

  string(icon, opts) {
    let id = handleIconId(icon);
    let classes = iconClasses(icon, opts) + " svg-string";

    return `<svg class="${classes}" xmlns="${SVG_NAMESPACE}"><use xlink:href="#${id}" /></svg>`;
  },

  node(icon, opts) {
    let id = handleIconId(icon);
    let classes = iconClasses(icon, opts) + " svg-node";

    return h(
      "svg",
      {
        attributes: { class: classes },
        namespace: SVG_NAMESPACE
      },
      [
        h("use", {
          "xlink:href": attributeHook("http://www.w3.org/1999/xlink", `#${id}`),
          namespace: SVG_NAMESPACE
        })
      ]
    );
  }
});
