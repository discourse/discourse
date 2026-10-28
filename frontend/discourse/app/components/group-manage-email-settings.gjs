import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import GroupManageSaveButton from "discourse/components/group-manage-save-button";
import GroupSmtpEmailSettings from "discourse/components/group-smtp-email-settings";
import { i18n } from "discourse-i18n";

export default class GroupManageEmailSettings extends Component {
  @service dialog;
  @service store;

  @tracked smtpSettingsValid = false;

  constructor() {
    super(...arguments);
    this._determineSettingsValid();
  }

  get emailSettingsValid() {
    return !get(this.args.group, "smtp_enabled") || this.smtpSettingsValid;
  }

  @action
  onChangeSmtpSettingsValid(valid) {
    this.smtpSettingsValid = valid;
  }

  @action
  smtpEnabledChange(event) {
    if (
      !event.target.checked &&
      this.args.group.smtp_enabled &&
      this._anySmtpFieldsFilled()
    ) {
      this.dialog.confirm({
        message: i18n("groups.manage.email.smtp_disable_confirm"),
        didConfirm: () => this.args.group.set("smtp_enabled", true),
      });
    }

    this.args.group.set("smtp_enabled", event.target.checked);
  }

  @action
  afterSave() {
    this.store.find("group", this.args.group.name).then(() => {
      this._determineSettingsValid();
    });
  }

  _determineSettingsValid() {
    this.smtpSettingsValid =
      this.args.group.smtp_enabled && this.args.group.smtp_server;
  }

  _anySmtpFieldsFilled() {
    return [
      this.args.group.smtp_server,
      this.args.group.smtp_port,
      this.args.group.email_username,
      this.args.group.email_password,
    ].some((value) => !isEmpty(value));
  }

  <template>
    <div class="group-manage-email-settings">
      <h3>{{i18n "groups.manage.email.smtp_title"}}</h3>
      <p>{{i18n "groups.manage.email.smtp_instructions"}}</p>

      <label for="enable_smtp">
        <Input
          id="enable_smtp"
          tabindex="1"
          @checked={{@group.smtp_enabled}}
          @type="checkbox"
          {{on "input" this.smtpEnabledChange}}
        />
        {{i18n "groups.manage.email.enable_smtp"}}
      </label>

      {{#if @group.smtp_enabled}}
        <GroupSmtpEmailSettings
          @group={{@group}}
          @onChangeSmtpSettingsValid={{this.onChangeSmtpSettingsValid}}
          @smtpSettingsValid={{this.smtpSettingsValid}}
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
              id="allow_unknown_sender_topic_replies"
              name="allow_unknown_sender_topic_replies"
              tabindex="13"
              @checked={{@group.allow_unknown_sender_topic_replies}}
              @type="checkbox"
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
        @afterSave={{this.afterSave}}
        @beforeSave={{@beforeSave}}
        @disabled={{not this.emailSettingsValid}}
        @model={{@group}}
        @tabindex="15"
      />
    </div>
  </template>
}
