/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { attributeBindings, tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";

@tagName("li")
@attributeBindings("topic.id:data-topic-id")
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
    {{icon this.topicStatusIcon}}

    <a href={{this.topic.lastUnreadUrl}} class="title">
      {{htmlSafe this.topic.fancyTitle}}
    </a>
  </template>
}
