import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import openLinksInNewTab from "discourse/plugins/discourse-events/discourse/modifiers/open-links-in-new-tab";

const BARE_URL_REGEX = /^https?:\/\/\S+$/;

export default class DiscoursePostEventLocation extends Component {
  get isBareLivestreamUrl() {
    return (
      this.args.event?.isZoomLivestream &&
      BARE_URL_REGEX.test(this.args.event.location ?? "")
    );
  }

  get locationHtml() {
    return this.isBareLivestreamUrl ? null : this.args.event?.locationHtml;
  }

  <template>
    {{#if this.locationHtml}}
      <section class="event__section event-location">
        {{dIcon "location-pin"}}

        <span
          class="event-location__text"
          {{openLinksInNewTab this.locationHtml}}
        >{{trustHTML this.locationHtml}}</span>
      </section>
    {{/if}}
  </template>
}
