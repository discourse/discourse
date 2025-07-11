import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
import ComboBox from "select-kit/components/combo-box";
import TagChooser from "select-kit/components/tag-chooser";
import ChannelData from "../channel-data";

export default class EditRule extends Component {
  @service siteSettings;

  @action
  async save(rule) {
    try {
      await rule.save();
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      {{on "submit" this.save}}
      @title={{i18n "chat_integration.edit_rule_modal.title"}}
      @closeModal={{@closeModal}}
      @tagName="form"
      id="chat-integration-edit-rule_modal"
    >
      <:body>
        <table>
          <tbody>
            <tr class="input">
              <td class="label">
                <label for="provider">
                  {{i18n "chat_integration.edit_rule_modal.provider"}}
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

            <tr class="input">
              <td class="label">
                <label for="channel">
                  {{i18n "chat_integration.edit_rule_modal.channel"}}
                </label>
              </td>
              <td>
                <ChannelData
                  @provider={{@model.provider}}
                  @channel={{@model.channel}}
                />
              </td>
            </tr>

            <tr class="chat-instructions">
              <td></td>
              <td></td>
            </tr>

            <tr class="input">
              <td class="label">
                <label for="filter">
                  {{i18n "chat_integration.edit_rule_modal.type"}}
                </label>
              </td>
              <td>
                <ComboBox
                  @name="type"
                  @content={{@model.rule.available_types}}
                  @value={{@model.rule.type}}
                  @onChange={{fn (mut @model.rule.type)}}
                />
              </td>
            </tr>

            <tr class="chat-instructions">
              <td></td>
              <td>
                <label>
                  {{i18n "chat_integration.edit_rule_modal.instructions.type"}}
                </label>
              </td>
            </tr>

            <tr class="input">
              <td class="label">
                <label for="filter">
                  {{i18n "chat_integration.edit_rule_modal.filter"}}
                </label>
              </td>
              <td>
                <ComboBox
                  @name="filter"
                  @content={{@model.rule.available_filters}}
                  @value={{@model.rule.filter}}
                  @onChange={{fn (mut @model.rule.filter)}}
                />
              </td>
            </tr>

            <tr class="chat-instructions">
              <td></td>
              <td>
                <label>
                  {{i18n
                    "chat_integration.edit_rule_modal.instructions.filter"
                  }}
                </label>
              </td>
            </tr>

            {{#if (eq @model.rule.type "normal")}}
              <tr class="input">
                <td class="label">
                  <label for="category">
                    {{i18n "chat_integration.edit_rule_modal.category"}}
                  </label>
                </td>
                <td>
                  <CategoryChooser
                    @name="category"
                    @options={{hash none="chat_integration.all_categories"}}
                    @value={{@model.rule.category_id}}
                    @onChange={{fn (mut @model.rule.category_id)}}
                  />
                </td>
              </tr>

              <tr class="chat-instructions">
                <td></td>
                <td>
                  <label>
                    {{i18n
                      "chat_integration.edit_rule_modal.instructions.category"
                    }}
                  </label>
                </td>
              </tr>
            {{else}}
              <tr class="input">
                <td class="label">
                  <label for="group">
                    {{i18n "chat_integration.edit_rule_modal.group"}}
                  </label>
                </td>
                <td>
                  <ComboBox
                    @content={{@model.groups}}
                    @valueProperty="id"
                    @value={{@model.rule.group_id}}
                    @onChange={{fn (mut @model.rule.group_id)}}
                    @options={{hash none="chat_integration.choose_group"}}
                  />
                </td>
              </tr>

              <tr class="chat-instructions">
                <td></td>
                <td>
                  <label>
                    {{i18n
                      "chat_integration.edit_rule_modal.instructions.group"
                    }}
                  </label>
                </td>
              </tr>
            {{/if}}

            {{#if this.siteSettings.tagging_enabled}}
              <tr class="input">
                <td class="label">
                  <label for="tags">
                    {{i18n "chat_integration.edit_rule_modal.tags"}}
                  </label>
                </td>
                <td>
                  <TagChooser
                    @placeholderKey="chat_integration.all_tags"
                    @name="tags"
                    @tags={{@model.rule.tags}}
                    @everyTag="true"
                    @onChange={{fn (mut @model.rule.tags)}}
                  />
                </td>
              </tr>

              <tr class="chat-instructions">
                <td></td>
                <td>
                  <label>
                    {{i18n
                      "chat_integration.edit_rule_modal.instructions.tags"
                    }}
                  </label>
                </td>
              </tr>
            {{/if}}
          </tbody>
        </table>
      </:body>

      <:footer>
        <DButton
          @action={{fn this.save @model.rule}}
          @label="chat_integration.edit_rule_modal.save"
          type="submit"
          id="save-rule"
          class="btn-primary btn-large"
        />

        <DButton
          @label="chat_integration.edit_rule_modal.cancel"
          @action={{@closeModal}}
          class="btn-large"
        />
      </:footer>
    </DModal>
  </template>
}
