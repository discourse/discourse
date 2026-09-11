import Component from "@glimmer/component";
import I18n, { i18n } from "discourse-i18n";
import DaBooleanField from "./fields/da-boolean-field.gjs";
import DaCategoriesField from "./fields/da-categories-field.gjs";
import DaCategoryField from "./fields/da-category-field.gjs";
import DaCategoryNotificationLevelField from "./fields/da-category-notification-level-field.gjs";
import DaChoicesField from "./fields/da-choices-field.gjs";
import DaCustomField from "./fields/da-custom-field.gjs";
import DaCustomFields from "./fields/da-custom-fields.gjs";
import DaDateTimeField from "./fields/da-date-time-field.gjs";
import DaEmailGroupUserField from "./fields/da-email-group-user-field.gjs";
import DaGroupField from "./fields/da-group-field.gjs";
import DaGroupsField from "./fields/da-groups-field.gjs";
import DaKeyValueField from "./fields/da-key-value-field.gjs";
import DaMessageField from "./fields/da-message-field.gjs";
import DaPeriodField from "./fields/da-period-field.gjs";
import DaPmsField from "./fields/da-pms-field.gjs";
import DaPostField from "./fields/da-post-field.gjs";
import DaRelativeTimeField from "./fields/da-relative-time-field.gjs";
import DaTagsField from "./fields/da-tags-field.gjs";
import DaTextField from "./fields/da-text-field.gjs";
import DaTextListField from "./fields/da-text-list-field.gjs";
import DaTrustLevelsField from "./fields/da-trust-levels-field.gjs";
import DaUserField from "./fields/da-user-field.gjs";
import DaUserProfileField from "./fields/da-user-profile-field.gjs";
import DaUsersField from "./fields/da-users-field.gjs";

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
  category_notification_level: DaCategoryNotificationLevelField,
  email_group_user: DaEmailGroupUserField,
  custom_field: DaCustomField,
  custom_fields: DaCustomFields,
  relative_time: DaRelativeTimeField,
};

export default class AutomationField extends Component {
  <template>
    {{#if this.displayField}}
      <this.component
        @description={{this.description}}
        @field={{@field}}
        @label={{this.label}}
        @placeholders={{@automation.placeholders}}
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
    if (
      I18n.lookup(this.translationKey, { locale: "en" }) ||
      I18n.lookup(this.translationKey)
    ) {
      return i18n(this.translationKey);
    }
  }
}
