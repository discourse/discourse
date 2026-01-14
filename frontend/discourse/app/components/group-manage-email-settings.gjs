/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import { on as onEvent } from "@ember-decorators/object";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import GroupSmtpEmailSettings from "discourse/components/group-smtp-email-settings";
import discourseComputed from "discourse/lib/decorators";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

@tagName("")
export default class GroupManageEmailSettings extends Component {
  @service dialog;

  smtpSettingsValid = false;

  @onEvent("init")
  _determineSettingsValid() {
    this.set(
      "smtpSettingsValid",
      this.group.smtp_enabled && this.group.smtp_server
    );
  }

  @discourseComputed("smtpSettingsValid", "group.smtp_enabled")
  emailSettingsValid(smtpSettingsValid, smtpEnabled) {
    return !smtpEnabled || smtpSettingsValid;
  }

  _anySmtpFieldsFilled() {
    return [
      this.group.smtp_server,
      this.group.smtp_port,
      this.group.email_username,
      this.group.email_password,
    ].some((value) => !isEmpty(value));
  }

  @action
  onChangeSmtpSettingsValid(valid) {
    this.set("smtpSettingsValid", valid);
  }

  @action
  smtpEnabledChange(event) {
    if (
      !event.target.checked &&
      this.group.smtp_enabled &&
      this._anySmtpFieldsFilled()
    ) {
      this.dialog.confirm({
        message: i18n("groups.manage.email.smtp_disable_confirm"),
        didConfirm: () => this.group.set("smtp_enabled", true),
      });
    }

    this.group.set("smtp_enabled", event.target.checked);
  }

  @action
  afterSave() {
    this.store.find("group", this.group.name).then(() => {
      this._determineSettingsValid();
    });
  }

  <template>
    <div class="group-manage-email-settings">
      <h3>{{i18n "groups.manage.email.smtp_title"}}</h3>
      <p>{{i18n "groups.manage.email.smtp_instructions"}}</p>

      <label for="enable_smtp">
        <Input
          @type="checkbox"
          @checked={{this.group.smtp_enabled}}
          id="enable_smtp"
          tabindex="1"
          {{on "input" this.smtpEnabledChange}}
        />
        {{i18n "groups.manage.email.enable_smtp"}}
      </label>

      {{#if this.group.smtp_enabled}}
        <GroupSmtpEmailSettings
          @group={{this.group}}
          @smtpSettingsValid={{this.smtpSettingsValid}}
          @onChangeSmtpSettingsValid={{this.onChangeSmtpSettingsValid}}
        />
      {{/if}}

      <div class="group-manage-email-additional-settings-wrapper">
        <div class="control-group">
          <h3>{{i18n "groups.manage.email.additional_settings"}}</h3>
          <label
            class="control-group-inline"
            for="allow_unknown_sender_topic_replies"
          >
            <Input
              @type="checkbox"
              name="allow_unknown_sender_topic_replies"
              id="allow_unknown_sender_topic_replies"
              @checked={{this.group.allow_unknown_sender_topic_replies}}
              tabindex="13"
            />
            <span>{{i18n
                "groups.manage.email.settings.allow_unknown_sender_topic_replies"
              }}</span>
          </label>
          <p>{{i18n
              "groups.manage.email.settings.allow_unknown_sender_topic_replies_hint"
            }}</p>
        </div>
      </div>

      <br />
      <GroupManageSaveButton
        @model={{this.group}}
        @disabled={{not this.emailSettingsValid}}
        @beforeSave={{this.beforeSave}}
        @afterSave={{this.afterSave}}
        @tabindex="15"
      />
    </div>
  </template>
}
