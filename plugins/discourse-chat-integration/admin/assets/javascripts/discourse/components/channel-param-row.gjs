import Component from "@glimmer/component";
import { concat, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import InputTip from "discourse/components/input-tip";
import { i18n } from "discourse-i18n";

export default class ChannelParamRow extends Component {
  get validation() {
    const value = this.args.channel.get(`data.${this.args.param.key}`);

    if (!value?.trim()) {
      return { failed: true };
    } else if (!this.args.param.regex) {
      return { ok: true };
    } else if (new RegExp(this.args.param.regex).test(value)) {
      return {
        ok: true,
        reason: i18n(
          "chat_integration.edit_channel_modal.channel_validation.ok"
        ),
      };
    } else {
      return {
        failed: true,
        reason: i18n(
          "chat_integration.edit_channel_modal.channel_validation.fail"
        ),
      };
    }
  }

  @action
  updateValue(event) {
    this.args.channel.set(`data.${this.args.param.key}`, event.target.value);
  }

  <template>
    <tr class="input">
      <td class="label">
        <label for="param-{{@param.key}}">
          {{i18n
            (concat
              "chat_integration.provider."
              @channel.provider
              ".param."
              @param.key
              ".title"
            )
          }}
        </label>
      </td>
      <td>
        <input
          {{on "input" this.updateValue}}
          value={{get @channel.data @param.key}}
          type="text"
          name="param-{{@param.key}}"
        />

        <InputTip @validation={{this.validation}} />
      </td>
    </tr>

    <tr class="chat-instructions">
      <td></td>
      <td>
        <label>
          {{i18n
            (concat
              "chat_integration.provider."
              @channel.provider
              ".param."
              @param.key
              ".help"
            )
          }}
        </label>
      </td>
    </tr>
  </template>
}
