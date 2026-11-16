import { withPluginApi } from "discourse/lib/plugin-api";
import LiveRoomOneboxPresence from "../components/live/room-onebox-presence.gjs";

const ROOM_SLUG_PATTERN = /\/live\/r\/([^/?#]+)/;

// Reads the slug from the card's link rather than a data attribute, so cards
// baked before presence existed get it without a rebake. The host isn't
// checked: the server only builds these cards for links it routes as local,
// which may use another of the site's hostnames, and the sanitizer keeps
// authors from writing one by hand.
export function roomSlug(card) {
  // Read the attribute, not the `href` property: cooked HTML can be decorated
  // in a detached document, where a relative link isn't resolved.
  const href = card
    .querySelector(".live-room-onebox__title a")
    ?.getAttribute("href");
  if (!href || !URL.canParse(href, window.location.origin)) {
    return null;
  }

  const match = new URL(href, window.location.origin).pathname.match(
    ROOM_SLUG_PATTERN
  );
  return match ? decodeURIComponent(match[1]) : null;
}

function decorateRoomOneboxes(element, helper) {
  element.querySelectorAll("aside.live-room-onebox").forEach((card) => {
    const slug = roomSlug(card);
    const body = card.querySelector(".live-room-onebox__body");
    if (
      !slug ||
      !body ||
      body.querySelector(".live-room-onebox__presence-mount")
    ) {
      return;
    }

    const mount = document.createElement("div");
    mount.className = "live-room-onebox__presence-mount";
    body.appendChild(mount);
    helper.renderGlimmer(mount, LiveRoomOneboxPresence, { slug });
  });
}

export default {
  name: "live-room-onebox-presence",

  initialize(owner) {
    if (!owner.lookup("service:site-settings").live_enabled) {
      return;
    }

    withPluginApi((api) => {
      api.decorateCookedElement(decorateRoomOneboxes);
      api.decorateChatMessage?.(decorateRoomOneboxes);
    });
  },
};
