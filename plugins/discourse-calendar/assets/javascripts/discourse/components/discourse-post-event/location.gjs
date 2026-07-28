import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const URL_SPLIT_REGEX = /(https?:\/\/\S+)/;
const URL_TEST_REGEX = /^https?:\/\/\S+$/;

// The location is a plain-text field, so it is deliberately not cooked as
// markdown: cooking tags a bare URL as a onebox, and the composer's onebox
// pass then embeds a full preview (e.g. a youtube player) inside the event
// card. Bare URLs — including livestream URLs, whose playable video renders
// separately at the bottom of the card — are rendered as plain links showing
// the raw URL instead.
export default class DiscoursePostEventLocation extends Component {
  get locationSegments() {
    return (this.location || "")
      .split(URL_SPLIT_REGEX)
      .filter((part) => part.length)
      .map((part) => ({ text: part, isUrl: URL_TEST_REGEX.test(part) }));
  }

  get location() {
    return this.args.event.location;
  }

  get isSingleUrlLocation() {
    return this.locationSegments.length === 1 && this.locationSegments[0].isUrl;
  }

  get singleUrl() {
    return this.isSingleUrlLocation ? this.locationSegments[0].text : null;
  }

  <template>
    {{#if this.location}}
      {{#if this.isSingleUrlLocation}}
        {{#unless @event.isZoomLivestream}}
          <section class="event__section event-location">
            {{dIcon "location-pin"}}

            <span class="event-location__text">
              <a
                href={{this.singleUrl}}
                target="_blank"
                rel="noopener noreferrer"
              >{{this.singleUrl}}</a>
            </span>
          </section>
        {{/unless}}
      {{else}}
        <section class="event__section event-location">
          {{dIcon "location-pin"}}

          <span class="event-location__text">
            {{~#each this.locationSegments as |segment|~}}
              {{~#if segment.isUrl~}}
                <a
                  href={{segment.text}}
                  target="_blank"
                  rel="noopener noreferrer"
                >{{segment.text}}</a>
              {{~else~}}
                {{segment.text}}
              {{~/if~}}
            {{~/each~}}
          </span>
        </section>
      {{/if}}
    {{/if}}
  </template>
}
