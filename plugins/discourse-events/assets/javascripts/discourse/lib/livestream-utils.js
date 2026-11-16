import { isEmpty } from "@ember/utils";
import { isDevelopment } from "discourse/lib/environment";

export function eventHasLivestream(event) {
  if (!event) {
    return false;
  }

  return event.livestream && !isEmpty(event.livestreamUrl);
}

export function shouldIgnoreZoomTimeframe(currentUser, event) {
  return (
    isDevelopment() &&
    Boolean(
      (currentUser?.staff ||
        (!currentUser && event?.allowAnonymousLivestream)) &&
      new URLSearchParams(window.location.search).get("showzoom")
    )
  );
}

export function zoomRouteOptions(currentUser, event) {
  return {
    queryParams: {
      showzoom: shouldIgnoreZoomTimeframe(currentUser, event) ? "1" : null,
    },
  };
}
