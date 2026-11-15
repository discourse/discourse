import { getOwner } from "@ember/owner";
import { i18n } from "discourse-i18n";
import { zoomRouteOptions } from "./livestream-utils.js";

export default function promptAnonymousLivestreamJoin(caller, event, register) {
  const owner = getOwner(caller);
  const { slug, id } = event.post.topic;
  const options = zoomRouteOptions(null, event);

  return owner.lookup("service:dialog").dialog({
    type: "confirm",
    title: i18n("discourse_events.livestream.zoom.guest_prompt.title"),
    message: i18n("discourse_events.livestream.zoom.guest_prompt.message"),
    buttons: [
      {
        label: i18n("discourse_events.livestream.zoom.guest_prompt.skip"),
        class: "btn-default",
        action: () =>
          owner
            .lookup("service:router")
            .transitionTo("topic-zoom", slug, id, options),
      },
      {
        label: i18n("discourse_events.livestream.zoom.guest_prompt.register"),
        class: "btn-primary",
        action:
          register ??
          (() => owner.lookup("route:application").send("showLogin")),
      },
    ],
  });
}
