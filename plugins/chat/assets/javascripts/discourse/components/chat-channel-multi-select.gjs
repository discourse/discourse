import Component from "@glimmer/component";
import { action } from "@ember/object";
import AsyncContent from "discourse/components/async-content";
import DButton from "discourse/components/d-button";
import DMultiSelect from "discourse/components/d-multi-select";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ChatChannelMultiSelect extends Component {
  initialIds = this.args.initialIds || [];

  @action
  async filterChannels(filter) {
    return await this.loadChannels({ filter });
  }

  @action
  async loadInitialSelection() {
    if (!this.initialIds?.length) {
      return [];
    }

    const channels = await this.loadChannels({ ids: this.initialIds });

    this.args.onChange?.(channels);
    return channels;
  }

  async loadChannels(data = { filter: null, ids: null }) {
    try {
      const response = await ajax("/chat/api/channels", {
        type: "GET",
        data,
      });

      return response.channels.map((channel) => ChatChannel.create(channel));
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <AsyncContent @asyncData={{this.loadInitialSelection}}>
      <:content>
        <DMultiSelect
          @selection={{@selection}}
          @loadFn={{this.filterChannels}}
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
