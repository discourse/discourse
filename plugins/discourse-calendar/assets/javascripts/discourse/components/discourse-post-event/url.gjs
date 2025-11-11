import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";

export default class DiscoursePostEventUrl extends Component {
  get url() {
    return this.args.url.includes("://") || this.args.url.includes("mailto:")
      ? this.args.url
      : `https://${this.args.url}`;
  }

  <template>
    {{#if @url}}
      <section class="event__section event-url">
        {{icon "link"}}
        <a
          class="url"
          href={{this.url}}
          target="_blank"
          rel="noopener noreferrer"
        >
          {{@url}}
        </a>
      </section>
    {{/if}}
  </template>
}
