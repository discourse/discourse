import Component, { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import { on as onEvent } from "@ember-decorators/object";
import { not } from "truth-helpers";
import GroupImapEmailSettings from "discourse/components/group-imap-email-settings";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import GroupSmtpEmailSettings from "discourse/components/group-smtp-email-settings";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

@tagName("")
export default class GroupManageEmailSettings extends Component {
  @service dialog;

  imapSettingsValid = false;
  smtpSettingsValid = false;

  @onEvent("init")
  _determineSettingsValid() {
    this.set(
      "imapSettingsValid",
      this.group.imap_enabled && this.group.imap_server
    );
    this.set(
      "smtpSettingsValid",
      this.group.smtp_enabled && this.group.smtp_server
    );
  }

  @discourseComputed(
    "emailSettingsValid",
    "group.smtp_enabled",
    "group.imap_enabled"
  )
  enableImapSettings(emailSettingsValid, smtpEnabled, imapEnabled) {
    return smtpEnabled && (emailSettingsValid || imapEnabled);
  }

  @discourseComputed(
    "smtpSettingsValid",
    "imapSettingsValid",
    "group.smtp_enabled",
    "group.imap_enabled"
  )
  emailSettingsValid(
    smtpSettingsValid,
    imapSettingsValid,
    smtpEnabled,
    imapEnabled
  ) {
    return (
      (!smtpEnabled || smtpSettingsValid) && (!imapEnabled || imapSettingsValid)
    );
  }

  _anySmtpFieldsFilled() {
    return [
      this.group.smtp_server,
      this.group.smtp_port,
      this.group.email_username,
      this.group.email_password,
    ].some((value) => !isEmpty(value));
  }

  _anyImapFieldsFilled() {
    return [this.group.imap_server, this.group.imap_port].some(
      (value) => !isEmpty(value)
    );
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
        didCancel: () => this.group.set("imap_enabled", false),
      });
    }

    this.group.set("smtp_enabled", event.target.checked);
  }

  @action
  imapEnabledChange(event) {
    if (
      !event.target.checked &&
      this.group.imap_enabled &&
      this._anyImapFieldsFilled()
    ) {
      this.dialog.confirm({
        message: i18n("groups.manage.email.imap_disable_confirm"),
        didConfirm: () => this.group.set("imap_enabled", true),
      });
    }

    this.group.set("imap_enabled", event.target.checked);
  }

  @action
  afterSave() {
    // reload the group to get the updated imap_mailboxes
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

      {{#if this.siteSettings.enable_imap}}
        <div class="group-manage-email-imap-wrapper">
          <br />

          <h3>{{i18n "groups.manage.email.imap_title"}}</h3>
          <p>
            {{htmlSafe (i18n "groups.manage.email.imap_instructions")}}
          </p>

          <div class="alert alert-warning">{{i18n
              "groups.manage.email.imap_alpha_warning"
            }}</div>

          <label for="enable_imap">
            <Input
              @type="checkbox"
              disabled={{not this.enableImapSettings}}
              @checked={{this.group.imap_enabled}}
              id="enable_imap"
              tabindex="8"
              {{on "input" this.imapEnabledChange}}
            />
            {{i18n "groups.manage.email.enable_imap"}}
          </label>

          {{#if this.group.imap_enabled}}
            <GroupImapEmailSettings
              @group={{this.group}}
              @imapSettingsValid={{this.imapSettingsValid}}
            />
          {{/if}}
        </div>
      {{/if}}

      <div class="group-manage-email-additional-settings-wrapper">
        <div class="control-group">
          <h3>{{i18n "groups.manage.email.imap_additional_settings"}}</h3>
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
