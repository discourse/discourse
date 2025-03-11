import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { attributeBindings, tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import discourseComputed from "discourse/lib/decorators";

@tagName("li")
@attributeBindings("topic.id:data-topic-id")
export default class CategoriesBoxesTopic extends Component {
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

  <template>
    {{icon this.topicStatusIcon}}

    <a href={{this.topic.lastUnreadUrl}} class="title">
      {{htmlSafe this.topic.fancyTitle}}
    </a>
  </template>
}
