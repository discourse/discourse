import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";

export default class TopicLink extends Component {
  @service prefetch;

  get url() {
    return this.args.topic.linked_post_number
      ? this.args.topic.urlForPostNumber(this.args.topic.linked_post_number)
      : this.args.topic.lastUnreadUrl;
  }

  @action
  triggerPrefetch() {
    this.prefetch.register(
      this.args.topic.id,
      this.args.topic.last_read_post_number
    );
  }

  <template>
    {{~! no whitespace ~}}
    <PluginOutlet @name="topic-link" @outletArgs={{lazyHash topic=@topic}}>
      {{~! no whitespace ~}}
      <a
        {{didInsert this.triggerPrefetch}}
        href={{this.url}}
        data-topic-id={{@topic.id}}
        class="title"
        ...attributes
      >{{htmlSafe @topic.fancyTitle}}</a>
      {{~! no whitespace ~}}
    </PluginOutlet>
    {{~! no whitespace ~}}
  </template>
}
