import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";

export default class ChatChannelListFilterToggle extends Component {
  @service chatChannelListPreferences;

  get bypassed() {
    return this.chatChannelListPreferences.isFilterBypassedFor(this.section);
  }

  get disabled() {
    return this.chatChannelListPreferences.isSavingFilterFor(this.section);
  }

  get section() {
    return this.args.section ?? "channels";
  }

  get visible() {
    return !this.chatChannelListPreferences.isDefaultFilterFor(this.section);
  }

  @action
  toggle() {
    this.chatChannelListPreferences.toggleFilter(this.section);
  }

  <template>
    {{#if this.visible}}
      <DButton
        class="btn-transparent chat-channel-list-filter-toggle title-action"
        ...attributes
        @action={{this.toggle}}
        @disabled={{this.disabled}}
        @icon={{if this.bypassed "filter" "filter-circle-xmark"}}
        @title={{if
          this.bypassed
          "chat.channel_list.apply_filters"
          "chat.channel_list.empty.show_all"
        }}
      />
    {{/if}}
  </template>
}
