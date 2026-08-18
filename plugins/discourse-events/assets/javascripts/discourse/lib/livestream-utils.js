import { isEmpty } from "@ember/utils";

export function eventHasLivestream(event) {
  if (!event) {
    return false;
  }

  return event.livestream && !isEmpty(event.livestreamUrl);
}
