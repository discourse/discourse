import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ComboBox from "discourse/select-kit/components/combo-box";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import { i18n } from "discourse-i18n";
import ChannelData from "../channel-data";

export default class EditRule extends Component {
  @service siteSettings;

  @tracked type = this.args.model.rule.type || "normal";
  @tracked filter = this.args.model.rule.filter || "watch";
  @tracked category_id = this.args.model.rule.category_id || null;
  @tracked group_id = this.args.model.rule.group_id || null;
  @tracked tags = this.args.model.rule.tags || [];

  get isNormalType() {
    return this.type === "normal";
  }

  @action
  onTypeChange(type) {
    this.type = type;
  }

  @action
  onFilterChange(filter) {
    this.filter = filter;
  }

  @action
  onCategoryChange(categoryId) {
    this.category_id = categoryId;
  }

  @action
  onGroupChange(groupId) {
    this.group_id = groupId;
  }

  @action
  onTagsChange(tags) {
    this.tags = tags;
  }

  @action
  async save() {
    const rule = this.args.model.rule;
    rule.setProperties({
      type: this.type,
      filter: this.filter,
      category_id: this.type === "normal" ? this.category_id : null,
      group_id: this.type !== "normal" ? this.group_id : null,
      // TODO (martin) This is a hack to get the tags working. We need to update
      // the server-side to accept an array of tag IDs or the tag objects.
      tags: this.tags.map((tag) => tag.name),
    });

    try {
      await rule.save();
      this.args.closeModal();
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <DModal
      @title={{i18n "chat_integration.edit_rule_modal.title"}}
      @closeModal={{@closeModal}}
      id="chat-integration-edit-rule-modal"
      class="chat-integration-modal"
    >
      <:body>
        <Form as |form|>
          <form.Field
            @name="provider"
            @title={{i18n "chat_integration.edit_rule_modal.provider"}}
            as |field|
          >
            <field.Custom>
              <span class="provider-name">
                {{i18n
                  (concat
                    "chat_integration.provider."
                    @model.channel.provider
                    ".title"
                  )
                }}
              </span>
            </field.Custom>
          </form.Field>

          <form.Field
            @name="channel"
            @title={{i18n "chat_integration.edit_rule_modal.channel"}}
            as |field|
          >
            <field.Custom>
              <ChannelData
                @provider={{@model.provider}}
                @channel={{@model.channel}}
              />
            </field.Custom>
          </form.Field>

          <form.Field
            @name="type"
            @title={{i18n "chat_integration.edit_rule_modal.type"}}
            @description={{i18n
              "chat_integration.edit_rule_modal.instructions.type"
            }}
            as |field|
          >
            <field.Custom>
              <ComboBox
                @content={{@model.rule.available_types}}
                @value={{this.type}}
                @onChange={{this.onTypeChange}}
              />
            </field.Custom>
          </form.Field>

          <form.Field
            @name="filter"
            @title={{i18n "chat_integration.edit_rule_modal.filter"}}
            @description={{i18n
              "chat_integration.edit_rule_modal.instructions.filter"
            }}
            as |field|
          >
            <field.Custom>
              <ComboBox
                @content={{@model.rule.available_filters}}
                @value={{this.filter}}
                @onChange={{this.onFilterChange}}
              />
            </field.Custom>
          </form.Field>

          {{#if this.isNormalType}}
            <form.Field
              @name="category_id"
              @title={{i18n "chat_integration.edit_rule_modal.category"}}
              @description={{i18n
                "chat_integration.edit_rule_modal.instructions.category"
              }}
              as |field|
            >
              <field.Custom>
                <CategoryChooser
                  @value={{this.category_id}}
                  @onChange={{this.onCategoryChange}}
                  @options={{hash none="chat_integration.all_categories"}}
                />
              </field.Custom>
            </form.Field>
          {{else}}
            <form.Field
              @name="group_id"
              @title={{i18n "chat_integration.edit_rule_modal.group"}}
              @description={{i18n
                "chat_integration.edit_rule_modal.instructions.group"
              }}
              as |field|
            >
              <field.Custom>
                <ComboBox
                  @content={{@model.groups}}
                  @valueProperty="id"
                  @value={{this.group_id}}
                  @onChange={{this.onGroupChange}}
                  @options={{hash none="chat_integration.choose_group"}}
                />
              </field.Custom>
            </form.Field>
          {{/if}}

          {{#if this.siteSettings.tagging_enabled}}
            <form.Field
              @name="tags"
              @title={{i18n "chat_integration.edit_rule_modal.tags"}}
              @description={{i18n
                "chat_integration.edit_rule_modal.instructions.tags"
              }}
              as |field|
            >
              <field.Custom>
                <TagChooser
                  @tags={{this.tags}}
                  @everyTag="true"
                  @onChange={{this.onTagsChange}}
                  @options={{hash placeholderKey="chat_integration.all_tags"}}
                />
              </field.Custom>
            </form.Field>
          {{/if}}

          <form.Actions>
            <form.Button
              @label="chat_integration.edit_rule_modal.save"
              @action={{this.save}}
              class="btn-primary"
              id="save-rule"
            />
            <form.Button
              @label="chat_integration.edit_rule_modal.cancel"
              @action={{@closeModal}}
              class="btn-default"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
