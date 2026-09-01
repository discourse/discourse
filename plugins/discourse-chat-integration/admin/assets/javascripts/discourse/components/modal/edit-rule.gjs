import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ComboBox from "discourse/select-kit/components/combo-box";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import getTagName from "../../lib/utilities";
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

  get title() {
    return this.args.model.rule.id
      ? i18n("chat_integration.edit_rule_modal.edit_title")
      : i18n("chat_integration.edit_rule_modal.create_title");
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
      tags: this.tags.map((tag) => getTagName(tag)),
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
      class="chat-integration-modal"
      id="chat-integration-edit-rule-modal"
      @closeModal={{@closeModal}}
      @title={{this.title}}
    >
      <:body>
        <Form as |form|>
          <form.Field
            @name="provider"
            @title={{i18n "chat_integration.edit_rule_modal.provider"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <span class="provider-name">
                {{i18n
                  (concat
                    "chat_integration.provider."
                    @model.channel.provider
                    ".title"
                  )
                }}
              </span>
            </field.Control>
          </form.Field>

          <form.Field
            @name="channel"
            @title={{i18n "chat_integration.edit_rule_modal.channel"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <ChannelData
                @channel={{@model.channel}}
                @provider={{@model.provider}}
              />
            </field.Control>
          </form.Field>

          <form.Field
            @description={{i18n
              "chat_integration.edit_rule_modal.instructions.type"
            }}
            @name="type"
            @title={{i18n "chat_integration.edit_rule_modal.type"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <ComboBox
                @content={{@model.rule.available_types}}
                @onChange={{this.onTypeChange}}
                @value={{this.type}}
              />
            </field.Control>
          </form.Field>

          <form.Field
            @description={{i18n
              "chat_integration.edit_rule_modal.instructions.filter"
            }}
            @name="filter"
            @title={{i18n "chat_integration.edit_rule_modal.filter"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <ComboBox
                @content={{@model.rule.available_filters}}
                @onChange={{this.onFilterChange}}
                @value={{this.filter}}
              />
            </field.Control>
          </form.Field>

          {{#if this.isNormalType}}
            <form.Field
              @description={{i18n
                "chat_integration.edit_rule_modal.instructions.category"
              }}
              @name="category_id"
              @title={{i18n "chat_integration.edit_rule_modal.category"}}
              @type="custom"
              as |field|
            >
              <field.Control>
                <CategoryChooser
                  @onChange={{this.onCategoryChange}}
                  @options={{hash none="chat_integration.all_categories"}}
                  @value={{this.category_id}}
                />
              </field.Control>
            </form.Field>
          {{else}}
            <form.Field
              @description={{i18n
                "chat_integration.edit_rule_modal.instructions.group"
              }}
              @name="group_id"
              @title={{i18n "chat_integration.edit_rule_modal.group"}}
              @type="custom"
              as |field|
            >
              <field.Control>
                <ComboBox
                  @content={{@model.groups}}
                  @onChange={{this.onGroupChange}}
                  @options={{hash none="chat_integration.choose_group"}}
                  @value={{this.group_id}}
                  @valueProperty="id"
                />
              </field.Control>
            </form.Field>
          {{/if}}

          {{#if this.siteSettings.tagging_enabled}}
            <form.Field
              @description={{i18n
                "chat_integration.edit_rule_modal.instructions.tags"
              }}
              @name="tags"
              @title={{i18n "chat_integration.edit_rule_modal.tags"}}
              @type="custom"
              as |field|
            >
              <field.Control>
                <TagChooser
                  @everyTag="true"
                  @onChange={{this.onTagsChange}}
                  @options={{hash placeholderKey="chat_integration.all_tags"}}
                  @tags={{this.tags}}
                />
              </field.Control>
            </form.Field>
          {{/if}}

          <form.Actions>
            <form.Button
              class="btn-primary"
              id="save-rule"
              @action={{this.save}}
              @label="chat_integration.edit_rule_modal.save"
            />
            <form.Button
              class="btn-default"
              @action={{@closeModal}}
              @label="chat_integration.edit_rule_modal.cancel"
            />
          </form.Actions>
        </Form>
      </:body>
    </DModal>
  </template>
}
