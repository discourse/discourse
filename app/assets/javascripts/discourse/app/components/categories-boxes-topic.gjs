import Component from "@ember/component";
import { attributeBindings, tagName } from "@ember-decorators/component";
import dIcon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import discourseComputed from "discourse/lib/decorators";

@tagName("li")
@attributeBindings("topic.id:data-topic-id")
export default class CategoriesBoxesTopic extends Component {
  <template>
    {{dIcon this.topicStatusIcon}}

    <a href={{this.topic.lastUnreadUrl}} class="title">
      {{htmlSafe this.topic.fancyTitle}}
    </a>
  </template>

  @discourseComputed("topic.pinned", "topic.closed", "topic.archived")
  topicStatusIcon(pinned, closed, archived) {
    if (pinned) {
      return "thumbtack";
    }
    if (closed || archived) {
      return "lock";
    }
    return "far-file-lines";
  }
}
