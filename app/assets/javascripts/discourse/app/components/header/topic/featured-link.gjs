import Component from "@glimmer/component";
import { extractLinkMeta } from "discourse/lib/render-topic-featured-link";
import icon from "discourse-common/helpers/d-icon";

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
