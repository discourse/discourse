import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import { i18n } from "discourse-i18n";
import getTagName from "../lib/utilities";

export default class RuleRow extends Component {
  @service siteSettings;
  @service dialog;

  get isCategory() {
    return this.args.rule.type === "normal";
  }

  get isMessage() {
    return this.args.rule.type === "group_message";
  }

  get isMention() {
    return this.args.rule.type === "group_mention";
  }

  get excludedCategories() {
    return (this.args.rule.exclude_category_ids || [])
      .map((id) => Category.findById(id))
      .filter(Boolean);
  }

  get displayTags() {
    const tags = this.args.rule.tags;
    if (!tags) {
      return null;
    }
    return tags.map((tag) => getTagName(tag)).join(", ");
  }

  @action
  delete(rule) {
    this.dialog.deleteConfirm({
      message: i18n("chat_integration.channel_delete_confirm"),
      didConfirm: () => {
        return rule
          .destroyRecord()
          .then(() => this.args.refresh())
          .catch(popupAjaxError);
      },
    });
  }

  <template>
    <tr class="d-table__row">
      <td class="d-table__cell --overview rule-filter">
        {{@rule.filterName}}
      </td>

      <td class="d-table__cell --detail rule-category">
        <div class="d-table__mobile-label">
          {{i18n "chat_integration.rule_table.category"}}
        </div>
        {{#if this.isCategory}}
          {{#if @rule.category}}
            {{dCategoryLink
              @rule.category
              allowUncategorized="true"
              link="false"
            }}
          {{else}}
            {{i18n "chat_integration.all_categories"}}
            {{#if this.excludedCategories.length}}
              <div class="rule-excluded-categories">
                {{i18n "chat_integration.excluding_categories"}}
                {{#each this.excludedCategories as |category|}}
                  {{dCategoryLink
                    category
                    allowUncategorized="true"
                    link="false"
                  }}
                {{/each}}
              </div>
            {{/if}}
          {{/if}}
        {{else if this.isMention}}
          {{i18n
            "chat_integration.group_mention_template"
            name=@rule.group_name
          }}
        {{else if this.isMessage}}
          {{i18n
            "chat_integration.group_message_template"
            name=@rule.group_name
          }}
        {{/if}}
      </td>

      {{#if this.siteSettings.tagging_enabled}}
        <td class="d-table__cell --detail rule-tags">
          <div class="d-table__mobile-label">
            {{i18n "chat_integration.rule_table.tags"}}
          </div>
          {{#if this.displayTags}}
            {{this.displayTags}}
          {{else}}
            {{i18n "chat_integration.all_tags"}}
          {{/if}}
        </td>
      {{/if}}

      <td class="d-table__cell --controls">
        <DButton
          @icon="pencil"
          @title="chat_integration.rule_table.edit_rule"
          @action={{fn @edit @rule}}
          class="btn-default btn-small edit"
        />
        <DButton
          @icon="trash-can"
          @title="chat_integration.rule_table.delete_rule"
          @action={{fn this.delete @rule}}
          class="btn-danger btn-small delete"
        />
      </td>
    </tr>
  </template>
}
