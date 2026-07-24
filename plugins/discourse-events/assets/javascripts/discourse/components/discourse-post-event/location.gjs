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
  get segments() {
    return (this.args.location || "")
      .split(URL_SPLIT_REGEX)
      .filter((part) => part.length)
      .map((part) => ({ text: part, isUrl: URL_TEST_REGEX.test(part) }));
  }

  <template>
    {{#if @location}}
      <section class="event__section event-location">
        {{dIcon "location-pin"}}

        <span class="event-location__text">
          {{~#each this.segments as |segment|~}}
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
  </template>
}
