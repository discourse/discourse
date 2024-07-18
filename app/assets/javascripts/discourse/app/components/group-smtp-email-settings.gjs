import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, getProperties } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import { or } from "truth-helpers";
import Form from "discourse/components/form";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { GROUP_SMTP_SSL_MODES } from "discourse/lib/constants";
import emailProviderDefaultSettings from "discourse/lib/email-provider-default-settings";
import i18n from "discourse-common/helpers/i18n";
import I18n from "I18n";

export default class GroupSmtpEmailSettings extends Component {
  @service currentUser;
  @service toasts;

  @tracked smtpSettingsValid = false;
  @tracked testingSettings = false;

  get sslModes() {
    return Object.keys(GROUP_SMTP_SSL_MODES).map((key) => {
      return {
        value: GROUP_SMTP_SSL_MODES[key],
        name: I18n.t(`groups.manage.email.ssl_modes.${key}`),
      };
    });
  }

  @cached
  get formData() {
    const form = getProperties(
      this.args.group,
      "email_username",
      "email_password",
      "email_from_alias",
      "smtp_server",
      "smtp_port",
      "smtp_ssl_mode"
    );

    form.smtp_ssl_mode ??= GROUP_SMTP_SSL_MODES.none;

    return form;
  }

  @action
  changeSmtpSettingsValid(newValidValue) {
    this.smtpSettingsValid = newValidValue;
    this.args.onChangeSmtpSettingsValid(newValidValue);
  }

  @action
  prefillSettings(provider, setData, event) {
    event?.preventDefault();
    const providerDefaults = emailProviderDefaultSettings(provider, "smtp");
    Object.keys(providerDefaults).forEach((key) => {
      setData(key, providerDefaults[key]);
    });
  }

  @action
  testSmtpSettings(data) {
    const settings = {
      host: data.smtp_server,
      port: data.smtp_port,
      ssl_mode: data.smtp_ssl_mode,
      username: data.email_username,
      password: data.email_password,
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
          smtp_server: data.smtp_server,
          smtp_port: data.smtp_port,
          smtp_ssl_mode: data.smtp_ssl_mode,
          email_username: data.email_username,
          email_from_alias: data.email_from_alias || "",
          email_password: data.email_password,
        });

        this.toasts.success({
          duration: 3000,
          data: { message: I18n.t("groups.manage.email.smtp_settings_valid") },
        });
      })
      .catch(popupAjaxError)
      .finally(() => (this.testingSettings = false));
  }

  <template>
    <div class="group-smtp-email-settings">
      <Form
        @data={{this.formData}}
        @onSubmit={{this.testSmtpSettings}}
        as |form|
      >
        <form.Field
          @name="smtp_server"
          @title={{i18n "groups.manage.email.credentials.smtp_server"}}
          @validation="required"
          as |field|
        >
          <field.Input />
        </form.Field>

        <form.Field
          @name="smtp_port"
          @title={{i18n "groups.manage.email.credentials.smtp_port"}}
          @validation="required"
          as |field|
        >
          <field.Input @type="number" />
        </form.Field>

        <form.Field
          @name="email_username"
          @title={{i18n "groups.manage.email.credentials.username"}}
          @validation="required"
          as |field|
        >
          <field.Input />
        </form.Field>

        <form.Field
          @name="email_password"
          @title={{i18n "groups.manage.email.credentials.password"}}
          @validation="required"
          as |field|
        >
          <field.Password />
        </form.Field>

        <form.Field
          @name="smtp_ssl_mode"
          @title={{i18n "groups.manage.email.credentials.smtp_ssl_mode"}}
          @validation="required"
          as |field|
        >
          <field.Select as |select|>
            {{#each this.sslModes as |sslMode|}}
              <select.Option
                @value={{sslMode.value}}
              >{{sslMode.name}}</select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

        <form.Field
          @name="email_from_alias"
          @title={{i18n "groups.manage.email.settings.from_alias"}}
          @description={{i18n "groups.manage.email.settings.from_alias_hint"}}
          as |field|
        >
          <field.Input />
        </form.Field>

        <form.Container class="group-smtp-prefill-options">
          {{i18n "groups.manage.email.prefill.title"}}
          <ul>
            <li>
              <a
                id="prefill_smtp_gmail"
                href
                {{on "click" (fn this.prefillSettings "gmail" form.set)}}
              >{{i18n "groups.manage.email.prefill.gmail"}}</a>
            </li>
            <li>
              <a
                id="prefill_smtp_outlook"
                href
                {{on "click" (fn this.prefillSettings "outlook" form.set)}}
              >{{i18n "groups.manage.email.prefill.outlook"}}</a>
            </li>
            <li>
              <a
                id="prefill_smtp_office365"
                href
                {{on "click" (fn this.prefillSettings "office365" form.set)}}
              >{{i18n "groups.manage.email.prefill.office365"}}</a>
            </li>
          </ul>
        </form.Container>

        <form.Submit
          @disabled={{or this.testingSettings}}
          @icon="cog"
          @label="groups.manage.email.test_settings"
          @title="groups.manage.email.settings_required"
          tabindex="7"
          class="btn-primary group-smtp-form__test-smtp-settings"
        />
      </Form>

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
