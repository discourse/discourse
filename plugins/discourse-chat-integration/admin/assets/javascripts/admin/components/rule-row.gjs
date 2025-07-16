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
    rule
      .destroyRecord()
      .then(() => this.args.refresh())
      .catch(popupAjaxError);
  }

  <template>
    <tr>
      <td>
        {{@rule.filterName}}
      </td>

      <td>
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

      <td>
        {{#if this.siteSettings.tagging_enabled}}
          {{#if @rule.tags}}
            {{@rule.tags}}
          {{else}}
            {{i18n "chat_integration.all_tags"}}
          {{/if}}
        {{/if}}
      </td>

      <td>
        <DButton
          @icon="pencil"
          @title="chat_integration.rule_table.edit_rule"
          @action={{fn @edit @rule}}
          class="edit"
        />

        <DButton
          @icon="far-trash-can"
          @title="chat_integration.rule_table.delete_rule"
          @action={{fn this.delete @rule}}
          class="delete"
        />
      </td>
    </tr>
  </template>
}
