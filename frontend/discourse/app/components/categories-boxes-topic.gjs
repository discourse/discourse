/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@tagName("")
export default class CategoriesBoxesTopic extends Component {
  @computed("topic.pinned", "topic.closed", "topic.archived")
  get topicStatusIcon() {
    if (this.topic?.pinned) {
      return "thumbtack";
    }
    if (this.topic?.closed || this.topic?.archived) {
      return "category.restricted";
    }
    return "far-file-lines";
  }

  <template>
    <li data-topic-id={{this.topic.id}} ...attributes>
      {{dIcon this.topicStatusIcon}}

      <a href={{this.topic.lastUnreadUrl}} class="title">
        {{trustHTML this.topic.fancyTitle}}
      </a>
    </li>
  </template>
}
