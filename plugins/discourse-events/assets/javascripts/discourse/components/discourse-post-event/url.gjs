import Component from "@glimmer/component";
import { samePrefix } from "discourse/lib/get-url";
import { prefixProtocol } from "discourse/lib/url";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class DiscoursePostEventUrl extends Component {
  get url() {
    return prefixProtocol(this.args.url);
  }

  // Same-site links stay in the tab so the app router can handle them.
  // Compare parsed origins: `DiscourseURL.isInternal` matches by prefix.
  get isExternal() {
    let parsed;
    try {
      parsed = new URL(this.url, window.location.origin);
    } catch {
      return true;
    }

    return parsed.origin !== window.location.origin || !samePrefix(parsed.href);
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
          target={{if this.isExternal "_blank"}}
        >
          {{this.label}}
        </a>
      </section>
    {{/if}}
  </template>
}
