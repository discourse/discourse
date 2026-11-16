import Component from "@glimmer/component";
import { prefixProtocol } from "discourse/lib/url";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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
      <section
        class={{dConcatClass
          "event__section event-url"
          (if @superseded "--superseded")
        }}
      >
        {{dIcon "link"}}
        <a
          class="url"
          href={{this.url}}
          rel="noopener noreferrer"
          target="_blank"
        >
          {{this.label}}
        </a>
      </section>
    {{/if}}
  </template>
}
