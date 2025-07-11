import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import ChannelParamRow from "../channel-param-row";

export default class EditChannel extends Component {
  get validParams() {
    return this.args.model.provider.channel_parameters.every((param) => {
      const value = this.args.model.channel.get(`data.${param.key}`);

      if (!value?.trim()) {
        return false;
      }

      if (!param.regex) {
        return true;
      }

      return new RegExp(param.regex).test(value);
    });
  }

  @action
  async save() {
    try {
      await this.args.model.channel.save();
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      {{on "submit" this.save}}
      @title={{i18n "chat_integration.edit_channel_modal.title"}}
      @closeModal={{@closeModal}}
      @tagName="form"
      id="chat-integration-edit-channel-modal"
    >
      <:body>
        <table>
          <tbody>
            <tr class="input">
              <td class="label">
                <label for="provider">
                  {{i18n "chat_integration.edit_channel_modal.provider"}}
                </label>
              </td>
              <td>
                {{i18n
                  (concat
                    "chat_integration.provider."
                    @model.channel.provider
                    ".title"
                  )
                }}
              </td>
            </tr>

            <tr class="chat-instructions">
              <td></td>
              <td></td>
            </tr>

            {{#each @model.provider.channel_parameters as |param|}}
              <ChannelParamRow @param={{param}} @channel={{@model.channel}} />
            {{/each}}
          </tbody>
        </table>
      </:body>

      <:footer>
        <DButton
          @action={{this.save}}
          @label="chat_integration.edit_channel_modal.save"
          @disabled={{not this.validParams}}
          type="submit"
          id="save-channel"
          class="btn-primary btn-large"
        />

        <DButton
          @action={{@closeModal}}
          @label="chat_integration.edit_channel_modal.cancel"
          class="btn-large"
        />
      </:footer>
    </DModal>
  </template>
}
