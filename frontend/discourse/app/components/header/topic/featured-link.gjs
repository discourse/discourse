import Component from "@glimmer/component";
import { extractLinkMeta } from "discourse/lib/render-topic-featured-link";
import dIcon from "discourse/ui-kit/helpers/d-icon";

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
        {{dIcon "up-right-from-square"}}
        {{this.meta.domain}}
      </a>
    {{/if}}
  </template>
}
