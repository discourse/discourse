import Component from "@glimmer/component";
import { service } from "@ember/service";
import { extractLinkMeta } from "discourse/lib/render-topic-featured-link";
import icon from "discourse-common/helpers/d-icon";

export default class FeaturedLink extends Component {
  @service header;

  get meta() {
    return extractLinkMeta(this.header.topic);
  }

  <template>
    {{#if this.meta}}
      <a
        class="topic-featured-link"
        rel={{this.meta.rel}}
        target={{this.meta.target}}
        href={{this.meta.href}}
      >
        {{icon "external-link-alt"}}
        {{this.meta.domain}}
      </a>
    {{/if}}
  </template>
}
