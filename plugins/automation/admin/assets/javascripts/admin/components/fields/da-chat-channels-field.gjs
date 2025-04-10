import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import MultiSelect from "select-kit/components/multi-select";
import BaseField from "./da-base-field";
import DAFieldDescription from "./da-field-description";
import DAFieldLabel from "./da-field-label";

export default class ChoicesField extends BaseField {
  @service chatChannelsManager;

  @tracked chatChannels = [];

  constructor() {
    super(...arguments);
    this.loadChatChannels();
  }

  loadChatChannels() {
    this.chatChannels = this.chatChannelsManager.publicMessageChannels.map(
      (channel) => {
        return {
          id: channel.id,
          name: channel.title,
        };
      }
    );
  }

  <template>
    <div class="field control-group">
      <DAFieldLabel @label={{@label}} @field={{@field}} />
      <div class="controls">
        <MultiSelect
          @content={{this.chatChannels}}
          @value={{@field.metadata.value}}
          @onChange={{this.mutValue}}
        />

        <DAFieldDescription @description={{@description}} />
      </div>
    </div>
  </template>
}
