import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { optionalRequire } from "discourse/lib/utilities";
import { eventHasLivestream } from "../../lib/livestream-utils";
import LivestreamZoomEntry from "../livestream/zoom-entry";

// Renders the event's livestream as a playable video at the bottom of the event
// card, from the cooked onebox served on the event (EventSerializer#livestream_
// onebox). For supported providers we hand the resolved attributes to lazy-
// videos' LazyVideo component (the post-stream decorator that normally does this
// doesn't reach our card); otherwise we render the onebox as-is.
export default class Livestream extends Component {
  @service siteSettings;

  get show() {
    return eventHasLivestream(this.args.event);
  }

  get isZoomLivestream() {
    return (
      this.siteSettings.livestream_zoom_enabled &&
      this.args.event?.livestreamUrl.includes("zoom.us")
    );
  }

  // Resolved at runtime: lazy-videos may not be installed, and resolving at
  // module load can return false before the plugin's modules are registered.
  get lazyVideo() {
    return optionalRequire(
      "discourse/plugins/discourse-lazy-videos/discourse/components/lazy-video"
    );
  }

  get videoAttributes() {
    const html = this.args.event?.livestreamOnebox;
    const getVideoAttributes = optionalRequire(
      "discourse/plugins/discourse-lazy-videos/lib/lazy-video-attributes"
    );
    if (!html || !getVideoAttributes || !this.lazyVideo) {
      return null;
    }

    const container = new DOMParser()
      .parseFromString(html, "text/html")
      .querySelector(".lazy-video-container");
    if (!container) {
      return null;
    }

    const attributes = getVideoAttributes(container);
    return this.siteSettings[`lazy_${attributes.providerName}_enabled`]
      ? attributes
      : null;
  }

  get hasLivestreamOnebox() {
    return !isEmpty(this.args.event?.livestreamOnebox);
  }

  get oneboxHtml() {
    return this.videoAttributes
      ? null
      : trustHTML(this.args.event?.livestreamOnebox ?? "");
  }

  <template>
    {{#if this.show}}
      <section class="event__section event-livestream">
        {{#if this.isZoomLivestream}}
          <LivestreamZoomEntry @event={{@event}} />
        {{else if this.hasLivestreamOnebox}}
          {{#if this.videoAttributes}}
            <this.lazyVideo @videoAttributes={{this.videoAttributes}} />
          {{else}}
            {{this.oneboxHtml}}
          {{/if}}
        {{/if}}
      </section>
    {{/if}}
  </template>
}
