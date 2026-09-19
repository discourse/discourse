import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, getProperties } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { GROUP_SMTP_SSL_MODES } from "discourse/lib/constants";
import emailProviderDefaultSettings from "discourse/lib/email-provider-default-settings";
import { or } from "discourse/truth-helpers";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import { i18n } from "discourse-i18n";

export default class GroupSmtpEmailSettings extends Component {
  @service toasts;

  @tracked smtpSettingsValid = false;
  @tracked testingSettings = false;

  get sslModes() {
    return Object.keys(GROUP_SMTP_SSL_MODES).map((key) => {
      return {
        value: GROUP_SMTP_SSL_MODES[key],
        name: i18n(`groups.manage.email.ssl_modes.${key}`),
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
          duration: "short",
          data: { message: i18n("groups.manage.email.smtp_settings_valid") },
        });
      })
      .catch(popupAjaxError)
      .finally(() => (this.testingSettings = false));
  }

  @action
  resetTestingSettings(field, value, { set }) {
    this.changeSmtpSettingsValid(false);
    set(field, value);
  }

  <template>
    <div class="group-smtp-email-settings">
      <Form
        @data={{this.formData}}
        @onSubmit={{this.testSmtpSettings}}
        as |form|
      >
        <form.Row as |row|>
          <row.Col @size={{6}}>
            <form.Field
              @name="smtp_server"
              @onSet={{fn this.resetTestingSettings "smtp_server"}}
              @title={{i18n "groups.manage.email.credentials.smtp_server"}}
              @type="input"
              @validation="required"
              as |field|
            >
              <field.Control />
            </form.Field>
          </row.Col>
          <row.Col @size={{6}}>
            <form.Field
              @name="email_username"
              @onSet={{fn this.resetTestingSettings "email_username"}}
              @title={{i18n "groups.manage.email.credentials.username"}}
              @type="input"
              @validation="required"
              as |field|
            >
              <field.Control />
            </form.Field>
          </row.Col>

          <row.Col @size={{6}}>
            <form.Field
              @name="smtp_port"
              @onSet={{fn this.resetTestingSettings "smtp_port"}}
              @title={{i18n "groups.manage.email.credentials.smtp_port"}}
              @type="input-number"
              @validation="required|integer"
              as |field|
            >
              <field.Control />
            </form.Field>
          </row.Col>
          <row.Col @size={{6}}>
            <form.Field
              @name="email_password"
              @onSet={{fn this.resetTestingSettings "email_password"}}
              @title={{i18n "groups.manage.email.credentials.password"}}
              @type="password"
              @validation="required"
              as |field|
            >
              <field.Control />
            </form.Field>
          </row.Col>

          <row.Col @size={{6}}>
            <form.Field
              @name="smtp_ssl_mode"
              @onSet={{fn this.resetTestingSettings "smtp_ssl_mode"}}
              @title={{i18n "groups.manage.email.credentials.smtp_ssl_mode"}}
              @type="select"
              @validation="required"
              as |field|
            >
              <field.Control as |select|>
                {{#each this.sslModes as |sslMode|}}
                  <select.Option
                    @value={{sslMode.value}}
                  >{{sslMode.name}}</select.Option>
                {{/each}}
              </field.Control>
            </form.Field>
          </row.Col>
          <row.Col @size={{6}}>
            <form.Field
              @description={{i18n
                "groups.manage.email.settings.from_alias_hint"
              }}
              @name="email_from_alias"
              @title={{i18n "groups.manage.email.settings.from_alias"}}
              @type="input"
              as |field|
            >
              <field.Control />
            </form.Field>
          </row.Col>
        </form.Row>

        <form.Submit
          class="btn-primary group-smtp-form__test-smtp-settings"
          tabindex="7"
          @disabled={{or this.testingSettings}}
          @icon="gear"
          @label="groups.manage.email.test_settings"
          @title="groups.manage.email.settings_required"
        />

        <form.Container class="group-smtp-prefill-options">
          {{i18n "groups.manage.email.prefill.title"}}
          <ul>
            <li>
              <a
                href
                id="prefill_smtp_gmail"
                {{on "click" (fn this.prefillSettings "gmail" form.set)}}
              >{{i18n "groups.manage.email.prefill.gmail"}}</a>
            </li>
            <li>
              <a
                href
                id="prefill_smtp_outlook"
                {{on "click" (fn this.prefillSettings "outlook" form.set)}}
              >{{i18n "groups.manage.email.prefill.outlook"}}</a>
            </li>
            <li>
              <a
                href
                id="prefill_smtp_office365"
                {{on "click" (fn this.prefillSettings "office365" form.set)}}
              >{{i18n "groups.manage.email.prefill.office365"}}</a>
            </li>
          </ul>
        </form.Container>
      </Form>

      {{#if @group.smtp_updated_at}}
        <div class=".group-smtp-form__last-updated-details">
          <small>
            {{i18n "groups.manage.email.last_updated"}}
            <strong>{{dFormatDate
                @group.smtp_updated_at
                leaveAgo="true"
              }}</strong>
            {{i18n "groups.manage.email.last_updated_by"}}
            <LinkTo
              @model={{@group.smtp_updated_by.username}}
              @route="user"
            >{{@group.smtp_updated_by.username}}</LinkTo>
          </small>
        </div>
      {{/if}}
    </div>
  </template>
}
