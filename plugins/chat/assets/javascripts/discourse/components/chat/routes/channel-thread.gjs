import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import ThreadHeader from "discourse/plugins/chat/discourse/components/chat/thread/header";
import Thread from "discourse/plugins/chat/discourse/components/chat-thread";

export default class ChatRoutesChannelThread extends Component {
  @tracked showfullTitle = false;

  @action
  setFullTitle(value) {
    this.showfullTitle = value;
  }

  <template>
    <div class="c-routes --channel-thread">
      {{#each (array @thread) as |thread|}}
        <ThreadHeader
          @thread={{thread}}
          @showFullTitle={{this.showfullTitle}}
        />

        <Thread
          @thread={{thread}}
          @targetMessageId={{@targetMessageId}}
          @includeHeader={{true}}
          @setFullTitle={{this.setFullTitle}}
        />
      {{/each}}
    </div>
  </template>
}
