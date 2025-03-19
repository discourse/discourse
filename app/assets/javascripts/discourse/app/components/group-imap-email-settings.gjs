import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import EmberObject, { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { isEmpty } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import { on as onEvent } from "@ember-decorators/object";
import { or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import emailProviderDefaultSettings from "discourse/lib/email-provider-default-settings";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

@tagName("")
export default class GroupImapEmailSettings extends Component {
  form = null;

  @discourseComputed(
    "group.email_username",
    "group.email_password",
    "form.imap_server",
    "form.imap_port"
  )
  missingSettings(email_username, email_password, imap_server, imap_port) {
    return [email_username, email_password, imap_server, imap_port].some(
      (value) => isEmpty(value)
    );
  }

  @discourseComputed("group.imap_mailboxes")
  mailboxes(imapMailboxes) {
    if (!imapMailboxes) {
      return [];
    }
    return imapMailboxes.map((mailbox) => ({ name: mailbox, value: mailbox }));
  }

  @discourseComputed("group.imap_mailbox_name", "mailboxes.length")
  mailboxSelected(mailboxName, mailboxesSize) {
    return mailboxesSize === 0 || !isEmpty(mailboxName);
  }

  @action
  resetSettingsValid() {
    this.set("imapSettingsValid", false);
  }

  @onEvent("init")
  _fillForm() {
    this.set(
      "form",
      EmberObject.create({
        imap_server: this.group.imap_server,
        imap_port: (this.group.imap_port || "").toString(),
        imap_ssl: this.group.imap_ssl,
      })
    );
  }

  @action
  prefillSettings(provider, event) {
    event?.preventDefault();
    this.form.setProperties(emailProviderDefaultSettings(provider, "imap"));
  }

  @action
  testImapSettings() {
    const settings = {
      host: this.form.imap_server,
      port: this.form.imap_port,
      ssl: this.form.imap_ssl,
      username: this.group.email_username,
      password: this.group.email_password,
    };

    this.set("testingSettings", true);
    this.set("imapSettingsValid", false);

    return ajax(`/groups/${this.group.id}/test_email_settings`, {
      type: "POST",
      data: Object.assign(settings, { protocol: "imap" }),
    })
      .then(() => {
        this.set("imapSettingsValid", true);
        this.group.setProperties({
          imap_server: this.form.imap_server,
          imap_port: this.form.imap_port,
          imap_ssl: this.form.imap_ssl,
        });
      })
      .catch(popupAjaxError)
      .finally(() => this.set("testingSettings", false));
  }

  <template>
    <div class="group-imap-email-settings">
      <form class="groups-form form-horizontal groups-form-imap">
        <div>
          <div class="control-group">
            <label for="imap_server">{{i18n
                "groups.manage.email.credentials.imap_server"
              }}</label>
            <Input
              @type="text"
              name="imap_server"
              @value={{this.form.imap_server}}
              tabindex="8"
              {{on "change" this.resetSettingsValid}}
            />
          </div>

          <label for="enable_ssl_imap" class="groups-form__enable-ssl">
            <Input
              @type="checkbox"
              @checked={{this.form.imap_ssl}}
              id="enable_ssl_imap"
              tabindex="11"
              {{on "change" this.resetSettingsValid}}
            />
            {{i18n "groups.manage.email.credentials.imap_ssl"}}
          </label>
        </div>

        <div>
          <div class="control-group">
            <label for="imap_port">{{i18n
                "groups.manage.email.credentials.imap_port"
              }}</label>
            <Input
              @type="text"
              name="imap_port"
              @value={{this.form.imap_port}}
              tabindex="9"
              {{on "change" (fn this.resetSettingsValid this.form.imap_port)}}
            />
          </div>
        </div>

        <div>
          <div class="control-group group-imap-mailboxes">
            {{#if this.mailboxes}}
              <label for="imap_mailbox_name">{{i18n
                  "groups.manage.email.mailboxes.synchronized"
                }}</label>
              <ComboBox
                @name="imap_mailbox_name"
                @id="imap_mailbox"
                @value={{this.group.imap_mailbox_name}}
                @valueProperty="value"
                @content={{this.mailboxes}}
                @tabindex="10"
                @onChange={{fn (mut this.group.imap_mailbox_name)}}
                @options={{hash none="groups.manage.email.mailboxes.disabled"}}
              />
            {{/if}}
          </div>

        </div>
      </form>

      <div class="control-group">
        <div class="group-imap-prefill-options">
          {{i18n "groups.manage.email.prefill.title"}}
          <a
            id="prefill_imap_gmail"
            href
            {{on "click" (fn this.prefillSettings "gmail")}}
          >{{i18n "groups.manage.email.prefill.gmail"}}</a>
        </div>
      </div>

      {{#unless this.mailboxSelected}}
        <div class="alert alert-error imap-no-mailbox-selected">
          {{i18n "groups.manage.email.imap_mailbox_not_selected"}}
        </div>
      {{/unless}}

      <div class="control-group buttons">
        <DButton
          @disabled={{or this.missingSettings this.testingSettings}}
          @action={{this.testImapSettings}}
          @icon="gear"
          @label="groups.manage.email.test_settings"
          @title="groups.manage.email.settings_required"
          tabindex="12"
          class="btn-primary test-imap-settings"
        />

        <ConditionalLoadingSpinner
          @size="small"
          @condition={{this.testingSettings}}
        />

        {{#if this.imapSettingsValid}}
          <span class="imap-settings-ok">
            {{icon "circle-check"}}
            {{i18n "groups.manage.email.imap_settings_valid"}}
          </span>
        {{/if}}
      </div>

      {{#if this.group.imap_updated_at}}
        <div class="group-email-last-updated-details for-imap">
          <small>
            {{i18n "groups.manage.email.last_updated"}}
            <strong>{{formatDate
                this.group.imap_updated_at
                leaveAgo="true"
              }}</strong>
            {{i18n "groups.manage.email.last_updated_by"}}
            <LinkTo
              @route="user"
              @model={{this.group.imap_updated_by.username}}
            >{{this.group.imap_updated_by.username}}</LinkTo>
          </small>
        </div>
      {{/if}}
    </div>
  </template>
}
