import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import stripWhitespace from "discourse/helpers/strip-whitespace";

export default class TopicLink extends Component {
  get url() {
    return this.args.topic.linked_post_number
      ? this.args.topic.urlForPostNumber(this.args.topic.linked_post_number)
      : this.args.topic.lastUnreadUrl;
  }

  <template>
    {{#stripWhitespace}}
      <PluginOutlet @name="topic-link" @outletArgs={{lazyHash topic=@topic}}>
        <a
          href={{this.url}}
          data-topic-id={{@topic.id}}
          class="title"
          ...attributes
        >{{htmlSafe @topic.fancyTitle}}{{yield}}</a>
      </PluginOutlet>
    {{/stripWhitespace}}
  </template>
}
