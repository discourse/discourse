import Component from "@glimmer/component";
import I18n, { i18n } from 'discourse-i18n';
import DaBooleanField from "./fields/da-boolean-field";
import DaCategoriesField from "./fields/da-categories-field";
import DaCategoryField from "./fields/da-category-field";
import DaCategoryNotificationlevelField from "./fields/da-category-notification-level-field";
import DaChoicesField from "./fields/da-choices-field";
import DaCustomField from "./fields/da-custom-field";
import DaCustomFields from "./fields/da-custom-fields";
import DaDateTimeField from "./fields/da-date-time-field";
import DaEmailGroupUserField from "./fields/da-email-group-user-field";
import DaGroupField from "./fields/da-group-field";
import DaGroupsField from "./fields/da-groups-field";
import DaKeyValueField from "./fields/da-key-value-field";
import DaMessageField from "./fields/da-message-field";
import DaPeriodField from "./fields/da-period-field";
import DaPmsField from "./fields/da-pms-field";
import DaPostField from "./fields/da-post-field";
import DaTagsField from "./fields/da-tags-field";
import DaTextField from "./fields/da-text-field";
import DaTextListField from "./fields/da-text-list-field";
import DaTrustLevelsField from "./fields/da-trust-levels-field";
import DaUserField from "./fields/da-user-field";
import DaUserProfileField from "./fields/da-user-profile-field";
import DaUsersField from "./fields/da-users-field";

const FIELD_COMPONENTS = {
  period: DaPeriodField,
  date_time: DaDateTimeField,
  text_list: DaTextListField,
  pms: DaPmsField,
  text: DaTextField,
  message: DaMessageField,
  categories: DaCategoriesField,
  user: DaUserField,
  users: DaUsersField,
  user_profile: DaUserProfileField,
  post: DaPostField,
  tags: DaTagsField,
  "key-value": DaKeyValueField,
  boolean: DaBooleanField,
  "trust-levels": DaTrustLevelsField,
  category: DaCategoryField,
  group: DaGroupField,
  groups: DaGroupsField,
  choices: DaChoicesField,
  category_notification_level: DaCategoryNotificationlevelField,
  email_group_user: DaEmailGroupUserField,
  custom_field: DaCustomField,
  custom_fields: DaCustomFields,
};

export default class AutomationField extends Component {
  <template>
    {{#if this.displayField}}
      <this.component
        @field={{@field}}
        @placeholders={{@automation.placeholders}}
        @label={{this.label}}
        @description={{this.description}}
        @saveAutomation={{@saveAutomation}}
      />
    {{/if}}
  </template>

  get component() {
    return FIELD_COMPONENTS[this.args.field.component];
  }

  get label() {
    return i18n(
      `discourse_automation${this.target}fields.${this.args.field.name}.label`
    );
  }

  get displayField() {
    const triggerId = this.args.automation?.trigger?.id;
    const triggerable = this.args.field?.triggerable;
    return triggerId && (!triggerable || triggerable === triggerId);
  }

  get placeholdersString() {
    return this.args.field.placeholders.join(", ");
  }

  get target() {
    return this.args.field.targetType === "script"
      ? `.scriptables.${this.args.automation.script.id.replace(/-/g, "_")}.`
      : `.triggerables.${this.args.automation.trigger.id.replace(/-/g, "_")}.`;
  }

  get translationKey() {
    return `discourse_automation${this.target}fields.${this.args.field.name}.description`;
  }

  get description() {
    return I18n.lookup(this.translationKey);
  }
}
