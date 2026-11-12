import Component from "@glimmer/component";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";

export default class ChatThreadHeading extends Component {
  get showHeading() {
    return this.args.thread?.title;
  }

  <template>
    {{#if this.showHeading}}
      <div class="chat-thread__heading">
        <div class="chat-thread__heading-icon">
          {{dIcon "discourse-threads"}}
        </div>
        <h2 class="chat-thread__heading-title">
          {{dReplaceEmoji @thread.title}}
        </h2>
      </div>
    {{/if}}
  </template>
}
