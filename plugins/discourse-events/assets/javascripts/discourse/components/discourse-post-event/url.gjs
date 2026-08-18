import Component from "@glimmer/component";
import { prefixProtocol } from "discourse/lib/url";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class DiscoursePostEventUrl extends Component {
  get url() {
    return prefixProtocol(this.args.url);
  }

  // Mirrors `EventParser.display_link` on the server.
  get label() {
    return (this.args.url ?? "").trim().replace(/^https?:\/\//i, "");
  }

  <template>
    {{#if @url}}
      <section class="event__section event-url">
        {{dIcon "link"}}
        <a
          class="url"
          href={{this.url}}
          target="_blank"
          rel="noopener noreferrer"
        >
          {{this.label}}
        </a>
      </section>
    {{/if}}
  </template>
}
