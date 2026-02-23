/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import discourseComputed from "discourse/lib/decorators";

@tagName("")
export default class CategoriesBoxesTopic extends Component {
  @discourseComputed("topic.pinned", "topic.closed", "topic.archived")
  topicStatusIcon(pinned, closed, archived) {
    if (pinned) {
      return "thumbtack";
    }
    if (closed || archived) {
      return "category.restricted";
    }
    return "far-file-lines";
  }

  <template>
    <li data-topic-id={{this.topic.id}} ...attributes>
      {{icon this.topicStatusIcon}}

      <a href={{this.topic.lastUnreadUrl}} class="title">
        {{htmlSafe this.topic.fancyTitle}}
      </a>
    </li>
  </template>
}
