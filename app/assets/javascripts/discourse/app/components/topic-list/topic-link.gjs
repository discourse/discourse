import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import { ForesightManager } from "js.foresight";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import PreloadStore from "discourse/lib/preload-store";

export default class TopicLink extends Component {
  get url() {
    return this.args.topic.linked_post_number
      ? this.args.topic.urlForPostNumber(this.args.topic.linked_post_number)
      : this.args.topic.lastUnreadUrl;
  }

  @action
  async prefetch() {
    const element = document.querySelector(
      `a.title[data-topic-id="${this.args.topic.id}"]`
    );

    ForesightManager.instance.register({
      element,
      callback: async () => {
        const data = {
          forceLoad: true,
          track_visit: false,
        };
        const nearPost = this.args.topic.last_read_post_number;
        const url = `/t/${this.args.topic.id}`;
        const jsonUrl = (nearPost ? `${url}/${nearPost}` : url) + ".json";
        // eslint-disable-next-line no-console
        console.log("Prefetching topic:", jsonUrl);
        const result = await ajax(jsonUrl, { data });
        PreloadStore.store(`topic_${this.args.topic.id}`, result);
      },
      unregisterOnCallback: true,
    });
  }

  <template>
    {{~! no whitespace ~}}
    <PluginOutlet @name="topic-link" @outletArgs={{lazyHash topic=@topic}}>
      {{~! no whitespace ~}}
      <a
        {{didInsert this.prefetch}}
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
