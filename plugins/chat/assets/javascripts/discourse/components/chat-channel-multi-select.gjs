import Component from "@glimmer/component";
import { action } from "@ember/object";
import AsyncContent from "discourse/components/async-content";
import DButton from "discourse/components/d-button";
import DMultiSelect from "discourse/components/d-multi-select";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ChatChannelMultiSelect extends Component {
  @action
  async loadChannels(filter) {
    try {
      const response = await ajax("/chat/api/channels", {
        type: "GET",
        data: { filter },
      });

      return response.channels.map((channel) => ChatChannel.create(channel));
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async loadInitialChannels() {
    try {
      const response = await ajax("/chat/api/channels", {
        type: "GET",
        data: { ids: this.args.selectedIds },
      });

      const channels = response.channels.map((channel) =>
        ChatChannel.create(channel)
      );

      await new Promise((resolve) => {
        setTimeout(() => {
          resolve();
        }, 1000);
      });

      this.args.onChange?.(channels);
      return channels;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <AsyncContent @asyncData={{this.loadInitialChannels}}>
      <:content>
        <DMultiSelect
          @selection={{@selection}}
          @loadFn={{this.loadChannels}}
          @onChange={{@onChange}}
        >
          <:selection as |result|>{{result.title}}</:selection>
          <:result as |result|>{{result.title}}</:result>
        </DMultiSelect>
      </:content>
      <:loading>
        <DButton
          @label="loading"
          @icon="spinner"
          @disabled={{true}}
          class="chat-channels-multi-select__loading"
        />
      </:loading>

    </AsyncContent>
  </template>
}
