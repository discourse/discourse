import Component from "@glimmer/component";
import { get } from "@ember/object";
import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export default class CategoriesBoxesTopic extends Component {
  // `pinned`, `closed` and `archived` are plain fields on the topic model, so they are
  // only tracked when read through `get`.
  get topicStatusIcon() {
    if (!this.args.topic) {
      return "far-file-lines";
    }
    if (get(this.args.topic, "pinned")) {
      return "thumbtack";
    }
    if (get(this.args.topic, "closed") || get(this.args.topic, "archived")) {
      return "category.restricted";
    }
    return "far-file-lines";
  }

  <template>
    <li data-topic-id={{@topic.id}} ...attributes>
      {{dIcon this.topicStatusIcon}}

      <a class="title" href={{@topic.lastUnreadUrl}}>
        {{trustHTML @topic.fancyTitle}}
      </a>
    </li>
  </template>
}
