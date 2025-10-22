import Component from "@glimmer/component";
import { service } from "@ember/service";
import AiGistToggle from "../../components/ai-gist-toggle";

export default class FilterGistToggle extends Component {
  @service topicThumbnails; // avoid Topic Thumbnails theme component

  get shouldShow() {
    return !this.topicThumbnails?.enabledForRoute;
  }

  <template>
    {{#if this.shouldShow}}
      <AiGistToggle />
    {{/if}}
  </template>
}
