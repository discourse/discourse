import Component from "@glimmer/component";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { eventHasLivestream } from "../../lib/livestream-utils";
import LivestreamZoomEntry from "../livestream/zoom-entry";
import OneboxEmbed from "./onebox-embed";

// Renders the event's livestream at the bottom of the event card, from the
// cooked onebox served on the event (EventSerializer#livestream_onebox).
export default class Livestream extends Component {
  @service siteSettings;

  // Once over, a recording supersedes the stream, which has nothing left to show.
  get show() {
    const { event } = this.args;
    return (
      eventHasLivestream(event) && !(event.isExpired && event.recordingUrl)
    );
  }

  get isZoomLivestream() {
    return (
      this.siteSettings.livestream_zoom_enabled &&
      this.args.event?.isZoomLivestream
    );
  }

  get hasLivestreamOnebox() {
    return !isEmpty(this.args.event?.livestreamOnebox);
  }

  <template>
    {{#if this.show}}
      <section class="event__section event-livestream">
        {{#if this.isZoomLivestream}}
          <LivestreamZoomEntry @event={{@event}} />
        {{else if this.hasLivestreamOnebox}}
          <OneboxEmbed @html={{@event.livestreamOnebox}} @post={{@post}} />
        {{/if}}
      </section>
    {{/if}}
  </template>
}
