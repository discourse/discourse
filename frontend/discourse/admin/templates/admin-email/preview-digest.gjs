import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import DatePickerPast from "discourse/components/date-picker-past";
import PluginOutlet from "discourse/components/plugin-outlet";
import ComboBox from "discourse/select-kit/components/combo-box";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default <template>
  <PluginOutlet @name="admin-email-preview-digest">
    <DPageSubheader
      @descriptionLabel={{i18n
        "admin.config.email.sub_pages.preview_summary.header_description"
      }}
    />

    <div class="admin-controls email-preview">
      <div class="controls">
        <div class="inline-form">
          <label for="email-preview-type-selector">{{i18n
              "admin.email.preview_type"
            }}</label>
          <ComboBox
            class="email-preview__type-selector"
            @content={{@controller.emailTypes}}
            @id="email-preview-type-selector"
            @onChange={{@controller.updateEmailType}}
            @options={{hash
              filterable=true
              headerAriaLabel=(i18n "admin.email.preview_type")
            }}
            @value={{@controller.emailType}}
            @valueProperty="value"
          />
          {{#if @controller.isDigest}}
            <label for="last-seen">{{i18n "admin.email.last_seen_user"}}</label>
            <DatePickerPast @id="last-seen" @value={{@controller.lastSeen}} />
          {{/if}}
          <label>{{i18n "admin.email.user"}}:</label>
          <EmailGroupUserChooser
            @onChange={{@controller.updateUsername}}
            @options={{hash
              maximum=1
              caretDownIcon="angle-down"
              caretUpIcon="angle-up"
            }}
            @value={{@controller.username}}
          />
          <label for="digest-locale-selector">{{i18n
              "admin.email.preview_locale"
            }}</label>
          <ComboBox
            class="email-preview__locale-selector"
            @content={{@controller.availableLocales}}
            @id="digest-locale-selector"
            @onChange={{@controller.updateLocale}}
            @options={{hash
              filterable=true
              headerAriaLabel=(i18n "admin.email.preview_locale")
              none="admin.email.preview_user_locale"
              clearable=true
            }}
            @value={{@controller.locale}}
            @valueProperty="value"
          />
          <label for="email-preview-theme-selector">{{i18n
              "admin.email.preview_theme"
            }}</label>
          <ComboBox
            class="email-preview__theme-selector"
            @content={{@controller.brandingThemes}}
            @id="email-preview-theme-selector"
            @onChange={{@controller.updateTheme}}
            @options={{hash
              filterable=true
              none="admin.email.preview_default_theme"
            }}
            @value={{@controller.themeId}}
            @valueProperty="value"
          />
          <DButton
            class="btn-primary digest-refresh-button"
            @action={{@controller.refresh}}
            @label="admin.email.refresh"
          />
          <div class="toggle">
            <label>{{i18n "admin.email.format"}}</label>
            {{#if @controller.showHtml}}
              <span>{{i18n "admin.email.html"}}</span>
              |
              <a
                class="show-text-link"
                href
                {{on "click" @controller.toggleShowHtml}}
              >
                {{i18n "admin.email.text"}}
              </a>
            {{else}}
              <a
                class="show-html-link"
                href
                {{on "click" @controller.toggleShowHtml}}
              >{{i18n "admin.email.html"}}</a>
              |
              <span>{{i18n "admin.email.text"}}</span>
            {{/if}}
          </div>
        </div>
      </div>
    </div>

    <DConditionalLoadingSpinner @condition={{@controller.loading}}>

      <div class="email-preview-digest">
        {{#if @controller.previewStale}}
          <p class="email-preview__stale alert alert-info">{{i18n
              "admin.email.preview_stale"
            }}</p>
        {{/if}}
        {{#if @controller.isTemplatePreview}}
          <div class="email-preview__template-notice alert alert-info">
            {{i18n "admin.email.template_preview_notice"}}
          </div>
        {{/if}}

        {{#if @controller.model.subject}}
          <p class="email-preview__subject">
            <strong>{{i18n "admin.email.preview_subject"}}:</strong>
            <span>{{@controller.model.subject}}</span>
          </p>
        {{/if}}

        {{#if @controller.showSendEmailForm}}
          <div class="controls">
            <div class="inline-form">
              {{#if @controller.sendingEmail}}
                {{i18n "admin.email.sending_test"}}
              {{else}}
                <label>{{i18n "admin.email.send_digest_label"}}</label>
                <DTextField
                  @placeholderKey="admin.email.test_email_address"
                  @value={{@controller.email}}
                />
                <DButton
                  class="btn-default"
                  @action={{@controller.sendEmail}}
                  @disabled={{@controller.sendEmailDisabled}}
                  @label="admin.email.send_digest"
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
                referrerpolicy="no-referrer"
                sandbox=""
                srcdoc={{@controller.model.html_content}}
                title={{i18n "admin.email.html_preview"}}
              ></iframe>
            {{/if}}
          {{else}}
            <pre>{{@controller.model.text_content}}</pre>
          {{/if}}
        </div>
      </div>

    </DConditionalLoadingSpinner>
  </PluginOutlet>
</template>
