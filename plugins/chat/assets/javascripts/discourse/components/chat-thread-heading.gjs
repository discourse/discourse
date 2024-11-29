import Component from "@glimmer/component";
import replaceEmoji from "discourse/helpers/replace-emoji";
import icon from "discourse-common/helpers/d-icon";

export default class ChatThreadHeading extends Component {
  get showHeading() {
    return this.args.thread?.title;
  }

  <template>
    {{#if this.showHeading}}
      <div class="chat-thread__heading">
        <div class="chat-thread__heading-icon">
          {{icon "discourse-threads"}}
        </div>
        <h2 class="chat-thread__heading-title">
          {{replaceEmoji @thread.title}}
        </h2>
      </div>
    {{/if}}
  </template>
}
