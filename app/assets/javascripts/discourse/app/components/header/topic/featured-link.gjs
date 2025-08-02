import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import { extractLinkMeta } from "discourse/lib/render-topic-featured-link";

export default class FeaturedLink extends Component {
  get meta() {
    return extractLinkMeta(this.args.topicInfo);
  }

  <template>
    {{#if this.meta}}
      <a
        class="topic-featured-link"
        rel={{this.meta.rel}}
        target={{this.meta.target}}
        href={{this.meta.href}}
      >
        {{icon "up-right-from-square"}}
        {{this.meta.domain}}
      </a>
    {{/if}}
  </template>
}
