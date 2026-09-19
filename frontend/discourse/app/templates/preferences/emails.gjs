import { fn, hash } from "@ember/helper";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import lazyHash from "discourse/helpers/lazy-hash";
import ComboBox from "discourse/select-kit/components/combo-box";
import DSaveControls from "discourse/ui-kit/d-save-controls";
import { i18n } from "discourse-i18n";

export default <template>
  <PluginOutlet
    @name="preferences-emails-wrapper"
    @outletArgs={{lazyHash controller=@controller}}
  >
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
          @content={{@controller.emailLevelOptions}}
          @id="user-email-messages-level"
          @onChange={{fn
            (mut @controller.model.user_option.email_messages_level)
          }}
          @value={{@controller.model.user_option.email_messages_level}}
          @valueProperty="value"
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
          @content={{@controller.emailLevelOptions}}
          @id="user-email-level"
          @onChange={{fn (mut @controller.model.user_option.email_level)}}
          @value={{@controller.model.user_option.email_level}}
          @valueProperty="value"
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
          @content={{@controller.previousRepliesOptions}}
          @onChange={{fn
            (mut @controller.model.user_option.email_previous_replies)
          }}
          @value={{@controller.model.user_option.email_previous_replies}}
          @valueProperty="value"
        />
      </div>
      <PreferenceCheckbox
        data-setting-name="user-email-in-reply-to"
        @checked={{@controller.model.user_option.email_in_reply_to}}
        @labelKey="user.email_in_reply_to"
      />

      <span>
        <PluginOutlet
          @connectorTagName="div"
          @name="user-preferences-emails-pref-email-settings"
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
          @checked={{@controller.model.user_option.email_digests}}
          @disabled={{@controller.model.user_option.mailing_list_mode}}
          @labelKey="user.email_digests.title"
        />
        {{#if @controller.model.user_option.email_digests}}
          <div
            class="controls controls-dropdown"
            data-setting-name="user-email-digests-frequency"
          >
            <ComboBox
              @content={{@controller.digestFrequencies}}
              @onChange={{fn
                (mut @controller.model.user_option.digest_after_minutes)
              }}
              @options={{hash filterable=true}}
              @value={{@controller.model.user_option.digest_after_minutes}}
              @valueProperty="value"
            />
          </div>
          <PreferenceCheckbox
            data-setting-name="user-include-tl0-in-digests"
            @checked={{@controller.model.user_option.include_tl0_in_digests}}
            @disabled={{@controller.model.user_option.mailing_list_mode}}
            @labelKey="user.include_tl0_in_digests"
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
          @checked={{@controller.model.user_option.mailing_list_mode}}
          @labelKey="user.mailing_list_mode.enabled"
        />
        <div class="instructions">
          {{trustHTML (i18n "user.mailing_list_mode.instructions")}}
        </div>
        {{#if @controller.model.user_option.mailing_list_mode}}
          <div
            class="controls controls-dropdown"
            data-setting-name="user-mailing-list-mode-options"
          >
            <ComboBox
              @content={{@controller.mailingListModeOptions}}
              @onChange={{fn
                (mut @controller.model.user_option.mailing_list_mode_frequency)
              }}
              @value={{@controller.model.user_option.mailing_list_mode_frequency}}
              @valueProperty="value"
            />
          </div>
        {{/if}}
      </div>
    {{/unless}}

    <span>
      <PluginOutlet
        @connectorTagName="div"
        @name="user-preferences-emails"
        @outletArgs={{lazyHash model=@controller.model save=@controller.save}}
      />
    </span>

    <br />

    <span>
      <PluginOutlet
        @connectorTagName="div"
        @name="user-custom-controls"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </span>

    <DSaveControls
      @action={{@controller.save}}
      @model={{@controller.model}}
      @saved={{@controller.saved}}
    />
  </PluginOutlet>
</template>
