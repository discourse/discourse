import Component from "@glimmer/component";
import DCookText from "discourse/ui-kit/d-cook-text";
import dIcon from "discourse/ui-kit/helpers/d-icon";

// For livestream events the location is the stream URL: show it as a plain link
// (the playable video renders separately at the bottom of the card) rather than
// letting DCookText onebox it into a thumbnail here.
export default class DiscoursePostEventLocation extends Component {
  get isLivestreamUrl() {
    return (
      this.args.livestream && /^https?:\/\//i.test(this.args.location ?? "")
    );
  }

  <template>
    {{#if @location}}
      <section class="event__section event-location">
        {{dIcon "location-pin"}}

        {{#if this.isLivestreamUrl}}
          <a href={{@location}} target="_blank" rel="noopener noreferrer">
            {{@location}}
          </a>
        {{else}}
          <DCookText @rawText={{@location}} />
        {{/if}}
      </section>
    {{/if}}
  </template>
}
