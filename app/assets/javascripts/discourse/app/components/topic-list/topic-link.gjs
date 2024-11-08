import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";

export default class TopicLink extends Component {
  get url() {
    return this.args.topic.linked_post_number
      ? this.args.topic.urlForPostNumber(this.args.topic.linked_post_number)
      : this.args.topic.lastUnreadUrl;
  }

  <template>
    {{~! no whitespace ~}}
    <a
      href={{this.url}}
      data-topic-id={{@topic.id}}
      role="heading"
      aria-level="2"
      class="title"
      ...attributes
    >{{htmlSafe @topic.fancyTitle}}</a>
    {{~! no whitespace ~}}
  </template>
}
