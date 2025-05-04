import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DatePickerPast from "discourse/components/date-picker-past";
import TextField from "discourse/components/text-field";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

export default RouteTemplate(
  <template>
    <DPageSubheader
      @descriptionLabel={{i18n
        "admin.config.email.sub_pages.preview_summary.header_description"
      }}
    />

    <div class="admin-controls email-preview">
      <div class="controls">
        <div class="inline-form">
          <label for="last-seen">{{i18n "admin.email.last_seen_user"}}</label>
          <DatePickerPast @value={{@controller.lastSeen}} @id="last-seen" />
          <label>{{i18n "admin.email.user"}}:</label>
          <EmailGroupUserChooser
            @value={{@controller.username}}
            @onChange={{@controller.updateUsername}}
            @options={{hash
              maximum=1
              caretDownIcon="caret-down"
              caretUpIcon="caret-up"
            }}
          />
          <DButton
            @action={{@controller.refresh}}
            @label="admin.email.refresh"
            class="btn-primary digest-refresh-button"
          />
          <div class="toggle">
            <label>{{i18n "admin.email.format"}}</label>
            {{#if @controller.showHtml}}
              <span>{{i18n "admin.email.html"}}</span>
              |
              <a
                href
                {{on "click" @controller.toggleShowHtml}}
                class="show-text-link"
              >
                {{i18n "admin.email.text"}}
              </a>
            {{else}}
              <a
                href
                {{on "click" @controller.toggleShowHtml}}
                class="show-html-link"
              >{{i18n "admin.email.html"}}</a>
              |
              <span>{{i18n "admin.email.text"}}</span>
            {{/if}}
          </div>
        </div>
      </div>
    </div>

    <ConditionalLoadingSpinner @condition={{@controller.loading}}>

      <div class="email-preview-digest">
        {{#if @controller.showSendEmailForm}}
          <div class="controls">
            <div class="inline-form">
              {{#if @controller.sendingEmail}}
                {{i18n "admin.email.sending_test"}}
              {{else}}
                <label>{{i18n "admin.email.send_digest_label"}}</label>
                <TextField
                  @value={{@controller.email}}
                  @placeholderKey="admin.email.test_email_address"
                />
                <DButton
                  @action={{@controller.sendEmail}}
                  @disabled={{@controller.sendEmailDisabled}}
                  @label="admin.email.send_digest"
                  class="btn-default"
                />
                {{#if @controller.sentEmail}}
                  <span class="result-message">{{i18n
                      "admin.email.sent_test"
                    }}</span>
                {{/if}}
              {{/if}}
            </div>
          </div>
        {{/if}}

        <div class="preview-output">
          {{#if @controller.showHtml}}
            {{#if @controller.htmlEmpty}}
              <p>{{i18n "admin.email.no_result"}}</p>
            {{else}}
              <iframe
                title={{i18n "admin.email.html_preview"}}
                srcdoc={{@controller.model.html_content}}
              ></iframe>
            {{/if}}
          {{else}}
            <pre>{{@controller.model.text_content}}</pre>
          {{/if}}
        </div>
      </div>

    </ConditionalLoadingSpinner>
  </template>
);
