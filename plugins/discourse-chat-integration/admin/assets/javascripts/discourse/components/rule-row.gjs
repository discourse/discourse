import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import categoryLink from "discourse/helpers/category-link";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

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
    <tr class="d-admin-row__content">
      <td class="d-admin-row__detail rule-filter">
        <div class="d-admin-row__mobile-label">
          {{i18n "chat_integration.rule_table.filter"}}
        </div>
        {{@rule.filterName}}
      </td>

      <td class="d-admin-row__detail rule-category">
        <div class="d-admin-row__mobile-label">
          {{i18n "chat_integration.rule_table.category"}}
        </div>
        {{#if this.isCategory}}
          {{#if @rule.category}}
            {{categoryLink
              @rule.category
              allowUncategorized="true"
              link="false"
            }}
          {{else}}
            {{i18n "chat_integration.all_categories"}}
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
        <td class="d-admin-row__detail rule-tags">
          <div class="d-admin-row__mobile-label">
            {{i18n "chat_integration.rule_table.tags"}}
          </div>
          {{#if @rule.tags}}
            {{@rule.tags}}
          {{else}}
            {{i18n "chat_integration.all_tags"}}
          {{/if}}
        </td>
      {{/if}}

      <td class="d-admin-row__controls">
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
