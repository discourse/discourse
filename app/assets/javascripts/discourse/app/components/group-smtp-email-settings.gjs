import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import formatDate from "discourse/helpers/format-date";
import withEventValue from "discourse/helpers/with-event-value";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { GROUP_SMTP_SSL_MODES } from "discourse/lib/constants";
import emailProviderDefaultSettings from "discourse/lib/email-provider-default-settings";
import dIcon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "I18n";
import ComboBox from "select-kit/components/combo-box";

export default class GroupSmtpEmailSettings extends Component {
  @service currentUser;

  @tracked smtpSettingsValid = false;
  @tracked testingSettings = false;

  form = new TrackedObject({
    email_username: this.args.group.email_username,
    email_password: this.args.group.email_password,
    email_from_alias: this.args.group.email_from_alias,
    smtp_server: this.args.group.smtp_server,
    smtp_port: (this.args.group.smtp_port || "").toString(),
    smtp_ssl_mode: this.args.group.smtp_ssl_mode || GROUP_SMTP_SSL_MODES.none,
  });

  get sslModes() {
    return Object.keys(GROUP_SMTP_SSL_MODES).map((key) => {
      return {
        value: GROUP_SMTP_SSL_MODES[key],
        name: I18n.t(`groups.manage.email.ssl_modes.${key}`),
      };
    });
  }

  get missingSettings() {
    if (!this.form) {
      return true;
    }
    return [
      this.form.email_username,
      this.form.email_password,
      this.form.smtp_server,
      this.form.smtp_port,
    ].some((value) => isEmpty(value));
  }

  @action
  changeSmtpSettingsValid(newValidValue) {
    this.smtpSettingsValid = newValidValue;
    this.args.onChangeSmtpSettingsValid(newValidValue);
  }

  @action
  onChangeSslMode(newMode) {
    this.form.smtp_ssl_mode = newMode;
    this.changeSmtpSettingsValid(false);
  }

  @action
  changeEmailUsername(newValue) {
    this.form.email_username = newValue;
    this.changeSmtpSettingsValid(false);
  }

  @action
  changeEmailPassword(newValue) {
    this.form.email_password = newValue;
    this.changeSmtpSettingsValid(false);
  }

  @action
  changeEmailFromAlias(newValue) {
    this.form.email_from_alias = newValue;
    this.changeSmtpSettingsValid(false);
  }

  @action
  changeSmtpServer(newValue) {
    this.form.smtp_server = newValue;
    this.changeSmtpSettingsValid(false);
  }

  @action
  changeSmtpPort(newValue) {
    this.form.smtp_port = newValue;
    this.changeSmtpSettingsValid(false);
  }

  @action
  prefillSettings(provider, event) {
    event?.preventDefault();
    Object.assign(this.form, emailProviderDefaultSettings(provider, "smtp"));
  }

  @action
  testSmtpSettings() {
    const settings = {
      host: this.form.smtp_server,
      port: this.form.smtp_port,
      ssl_mode: this.form.smtp_ssl_mode,
      username: this.form.email_username,
      password: this.form.email_password,
    };

    this.testingSettings = true;
    this.changeSmtpSettingsValid(false);

    return ajax(`/groups/${this.args.group.id}/test_email_settings`, {
      type: "POST",
      data: Object.assign(settings, { protocol: "smtp" }),
    })
      .then(() => {
        this.changeSmtpSettingsValid(true);
        this.args.group.setProperties({
          smtp_server: this.form.smtp_server,
          smtp_port: this.form.smtp_port,
          smtp_ssl_mode: this.form.smtp_ssl_mode,
          email_username: this.form.email_username,
          email_from_alias: this.form.email_from_alias,
          email_password: this.form.email_password,
        });
      })
      .catch(popupAjaxError)
      .finally(() => (this.testingSettings = false));
  }

  <template>
    <div class="group-smtp-email-settings">
      <form class="groups-form form-horizontal group-smtp-form">
        <div>
          <div class="control-group">
            <label for="username">{{i18n
                "groups.manage.email.credentials.username"
              }}</label>
            <input
              type="text"
              name="username"
              class="group-smtp-form__smtp-username"
              value={{this.form.email_username}}
              tabindex="1"
              {{on "input" (withEventValue this.changeEmailUsername)}}
            />
          </div>

          <div class="control-group">
            <label for="smtp_server">{{i18n
                "groups.manage.email.credentials.smtp_server"
              }}</label>
            <input
              type="text"
              name="smtp_server"
              class="group-smtp-form__smtp-server"
              value={{this.form.smtp_server}}
              tabindex="4"
              {{on "input" (withEventValue this.changeSmtpServer)}}
            />
          </div>

          <div class="control-group">
            <label for="smtp_ssl_mode">
              {{i18n "groups.manage.email.credentials.smtp_ssl_mode"}}
            </label>
            <ComboBox
              @content={{this.sslModes}}
              @valueProperty="value"
              @value={{this.form.smtp_ssl_mode}}
              name="smtp_ssl_mode"
              class="group-smtp-form__smtp-ssl-mode"
              tabindex="6"
              @onChange={{this.onChangeSslMode}}
            />
          </div>
        </div>

        <div>
          <div class="control-group">
            <label for="password">{{i18n
                "groups.manage.email.credentials.password"
              }}</label>
            <input
              type="password"
              name="password"
              class="group-smtp-form__smtp-password"
              value={{this.form.email_password}}
              tabindex="2"
              {{on "input" (withEventValue this.changeEmailPassword)}}
            />
          </div>

          <div class="control-group">
            <label for="smtp_port">{{i18n
                "groups.manage.email.credentials.smtp_port"
              }}</label>
            <input
              type="text"
              name="smtp_port"
              class="group-smtp-form__smtp-port"
              value={{this.form.smtp_port}}
              tabindex="5"
              {{on "input" (withEventValue this.changeSmtpPort)}}
            />
          </div>
        </div>

        <div>
          <div class="control-group">
            <label for="from_alias">{{i18n
                "groups.manage.email.settings.from_alias"
              }}</label>
            <input
              type="text"
              name="from_alias"
              class="group-smtp-form__smtp-from-alias"
              id="from_alias"
              value={{this.form.email_from_alias}}
              {{on "input" (withEventValue this.changeEmailFromAlias)}}
              tabindex="3"
            />
            <p>{{i18n "groups.manage.email.settings.from_alias_hint"}}</p>
          </div>
        </div>
      </form>

      <div class="control-group">
        <div class="group-smtp-prefill-options">
          {{i18n "groups.manage.email.prefill.title"}}
          <ul>
            <li>
              <a
                id="prefill_smtp_gmail"
                href
                {{on "click" (fn this.prefillSettings "gmail")}}
              >{{i18n "groups.manage.email.prefill.gmail"}}</a>
            </li>
            <li>
              <a
                id="prefill_smtp_outlook"
                href
                {{on "click" (fn this.prefillSettings "outlook")}}
              >{{i18n "groups.manage.email.prefill.outlook"}}</a>
            </li>
            <li>
              <a
                id="prefill_smtp_office365"
                href
                {{on "click" (fn this.prefillSettings "office365")}}
              >{{i18n "groups.manage.email.prefill.office365"}}</a>
            </li>
          </ul>
        </div>
      </div>

      <div class="control-group buttons">
        <DButton
          @disabled={{or this.missingSettings this.testingSettings}}
          @action={{this.testSmtpSettings}}
          @icon="cog"
          @label="groups.manage.email.test_settings"
          @title="groups.manage.email.settings_required"
          tabindex="7"
          class="btn-primary group-smtp-form__test-smtp-settings"
        />

        <ConditionalLoadingSpinner
          @size="small"
          @condition={{this.testingSettings}}
        />

        {{#if @smtpSettingsValid}}
          <span class="group-smtp-form__smtp-settings-ok">
            {{dIcon "check-circle"}}
            {{i18n "groups.manage.email.smtp_settings_valid"}}
          </span>
        {{/if}}
      </div>

      {{#if @group.smtp_updated_at}}
        <div class=".group-smtp-form__last-updated-details">
          <small>
            {{i18n "groups.manage.email.last_updated"}}
            <strong>{{formatDate
                @group.smtp_updated_at
                leaveAgo="true"
              }}</strong>
            {{i18n "groups.manage.email.last_updated_by"}}
            <LinkTo
              @route="user"
              @model={{@group.smtp_updated_by.username}}
            >{{@group.smtp_updated_by.username}}</LinkTo>
          </small>
        </div>
      {{/if}}
    </div>
  </template>
}
