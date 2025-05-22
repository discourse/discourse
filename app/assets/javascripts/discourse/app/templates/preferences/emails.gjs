import { fn, hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import PluginOutlet from "discourse/components/plugin-outlet";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import SaveControls from "discourse/components/save-controls";
import htmlSafe from "discourse/helpers/html-safe";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    {{#unless @controller.siteSettings.disable_mailing_list_mode}}
      {{~#if @controller.model.user_option.mailing_list_mode}}
        <div class="warning-wrap">
          <div class="warning">{{i18n "user.mailing_list_mode.warning"}}</div>
        </div>
      {{/if}}
    {{/unless}}
    <div class="control-group pref-email-settings">
      <label class="control-label">{{i18n "user.email_settings"}}</label>

      <div
        class="controls controls-dropdown"
        data-setting-name="user-email-messages-level"
      >
        <label for="user-email-messages-level">{{i18n
            "user.email_messages_level"
          }}</label>
        <ComboBox
          @valueProperty="value"
          @content={{@controller.emailLevelOptions}}
          @value={{@controller.model.user_option.email_messages_level}}
          @id="user-email-messages-level"
          @onChange={{fn
            (mut @controller.model.user_option.email_messages_level)
          }}
        />
        {{#if @controller.emailMessagesLevelAway}}
          <div
            class="instructions"
          >{{@controller.emailFrequencyInstructions}}</div>
        {{/if}}
      </div>

      <div
        class="controls controls-dropdown"
        data-setting-name="user-email-level"
      >
        <label for="user-email-level">{{i18n "user.email_level.title"}}</label>
        <ComboBox
          @valueProperty="value"
          @content={{@controller.emailLevelOptions}}
          @value={{@controller.model.user_option.email_level}}
          @id="user-email-level"
          @onChange={{fn (mut @controller.model.user_option.email_level)}}
        />
        {{#if @controller.emailLevelAway}}
          <div
            class="instructions"
          >{{@controller.emailFrequencyInstructions}}</div>
        {{/if}}
      </div>

      <div
        class="controls controls-dropdown"
        data-setting-name="user-email-previous-replies"
      >
        <label>{{i18n "user.email_previous_replies.title"}}</label>
        <ComboBox
          @valueProperty="value"
          @content={{@controller.previousRepliesOptions}}
          @value={{@controller.model.user_option.email_previous_replies}}
          @onChange={{fn
            (mut @controller.model.user_option.email_previous_replies)
          }}
        />
      </div>
      <PreferenceCheckbox
        data-setting-name="user-email-in-reply-to"
        @labelKey="user.email_in_reply_to"
        @checked={{@controller.model.user_option.email_in_reply_to}}
      />

      <span>
        <PluginOutlet
          @name="user-preferences-emails-pref-email-settings"
          @connectorTagName="div"
          @outletArgs={{lazyHash model=@controller.model save=@controller.save}}
        />
      </span>
    </div>

    {{#unless @controller.siteSettings.disable_digest_emails}}
      <div class="control-group pref-activity-summary">
        <label class="control-label">{{i18n
            "user.email_activity_summary"
          }}</label>
        <PreferenceCheckbox
          data-setting-name="user-email-digests"
          @labelKey="user.email_digests.title"
          @disabled={{@controller.model.user_option.mailing_list_mode}}
          @checked={{@controller.model.user_option.email_digests}}
        />
        {{#if @controller.model.user_option.email_digests}}
          <div
            class="controls controls-dropdown"
            data-setting-name="user-email-digests-frequency"
          >
            <ComboBox
              @valueProperty="value"
              @content={{@controller.digestFrequencies}}
              @value={{@controller.model.user_option.digest_after_minutes}}
              @onChange={{fn
                (mut @controller.model.user_option.digest_after_minutes)
              }}
              @options={{hash filterable=true}}
            />
          </div>
          <PreferenceCheckbox
            data-setting-name="user-include-tl0-in-digests"
            @labelKey="user.include_tl0_in_digests"
            @disabled={{@controller.model.user_option.mailing_list_mode}}
            @checked={{@controller.model.user_option.include_tl0_in_digests}}
          />
        {{/if}}
      </div>
    {{/unless}}

    {{#unless @controller.siteSettings.disable_mailing_list_mode}}
      <div class="control-group pref-mailing-list-mode">
        <label class="control-label">{{i18n
            "user.mailing_list_mode.label"
          }}</label>
        <PreferenceCheckbox
          data-setting-name="user-mailing-list-mode-enabled"
          @labelKey="user.mailing_list_mode.enabled"
          @checked={{@controller.model.user_option.mailing_list_mode}}
        />
        <div class="instructions">
          {{htmlSafe (i18n "user.mailing_list_mode.instructions")}}
        </div>
        {{#if @controller.model.user_option.mailing_list_mode}}
          <div
            class="controls controls-dropdown"
            data-setting-name="user-mailing-list-mode-options"
          >
            <ComboBox
              @valueProperty="value"
              @content={{@controller.mailingListModeOptions}}
              @value={{@controller.model.user_option.mailing_list_mode_frequency}}
              @onChange={{fn
                (mut @controller.model.user_option.mailing_list_mode_frequency)
              }}
            />
          </div>
        {{/if}}
      </div>
    {{/unless}}

    <span>
      <PluginOutlet
        @name="user-preferences-emails"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model save=@controller.save}}
      />
    </span>

    <br />

    <span>
      <PluginOutlet
        @name="user-custom-controls"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </span>

    <SaveControls
      @model={{@controller.model}}
      @action={{@controller.save}}
      @saved={{@controller.saved}}
    />
  </template>
);
