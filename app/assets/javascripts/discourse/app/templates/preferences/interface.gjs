import { fn, hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import SaveControls from "discourse/components/save-controls";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <span>
      <PluginOutlet
        @name="user-preferences-interface-top"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@controller.model save=@controller.save}}
      />
    </span>

    {{#if @controller.showThemeSelector}}
      <div class="control-group theme" data-setting-name="user-theme">
        <label class="control-label">{{i18n "user.theme"}}</label>
        <div class="controls">
          <ComboBox
            @content={{@controller.userSelectableThemes}}
            @value={{@controller.themeId}}
          />
        </div>
        {{#if @controller.themeIdChanged}}
          <p class="alert alert-success save-theme-alert">{{i18n
              "user.save_to_change_theme"
              save_text=(i18n "save")
            }}</p>
        {{/if}}
        {{#if @controller.showThemeSetDefault}}
          <div class="controls">
            <PreferenceCheckbox
              @labelKey="user.theme_default_on_all_devices"
              @checked={{@controller.makeThemeDefault}}
            />
          </div>
        {{/if}}
      </div>
    {{/if}}

    {{#if @controller.showColorSchemeSelector}}
      <fieldset
        class="control-group color-scheme"
        data-setting-name="user-color-scheme"
      >
        <legend class="control-label">{{i18n "user.color_scheme"}}</legend>
        <div class="controls">
          <div class="control-subgroup light-color-scheme">
            {{#if @controller.showDarkColorSchemeSelector}}
              <div class="instructions">{{i18n
                  "user.color_schemes.regular"
                }}</div>
            {{/if}}
            <div class="controls">
              <ComboBox
                @content={{@controller.userSelectableColorSchemes}}
                @value={{@controller.selectedColorSchemeId}}
                @onChange={{@controller.loadColorScheme}}
                @options={{hash
                  translatedNone=@controller.selectedColorSchemeNoneLabel
                  autoInsertNoneItem=@controller.showColorSchemeNoneItem
                }}
              />
            </div>
          </div>
          {{#if @controller.showDarkColorSchemeSelector}}
            <div class="control-subgroup dark-color-scheme">
              <div class="instructions">{{i18n "user.color_schemes.dark"}}</div>
              <div class="controls">
                <ComboBox
                  @content={{@controller.userSelectableDarkColorSchemes}}
                  @value={{@controller.selectedDarkColorSchemeId}}
                  @onChange={{@controller.loadDarkColorScheme}}
                />
              </div>
            </div>
          {{/if}}
        </div>
        {{#if @controller.previewingColorScheme}}
          {{#if @controller.previewingColorScheme}}
            <DButton
              @action={{@controller.undoColorSchemePreview}}
              @label="user.color_schemes.undo"
              @icon="arrow-rotate-left"
              class="btn-default btn-small undo-preview"
            />
          {{/if}}
          <div class="controls color-scheme-checkbox">
            <PreferenceCheckbox
              @labelKey="user.color_scheme_default_on_all_devices"
              @checked={{@controller.makeColorSchemeDefault}}
            />
          </div>
        {{/if}}
        {{#if @controller.showDarkColorSchemeSelector}}
          <div class="instructions">
            {{i18n "user.color_schemes.dark_instructions"}}
          </div>
        {{/if}}
      </fieldset>
    {{/if}}

    {{#if @controller.showDarkModeToggle}}
      <div class="control-group dark-mode" data-setting-name="user-dark-mode">
        <label class="control-label">{{i18n "user.dark_mode"}}</label>
        <div class="controls">
          <PreferenceCheckbox
            @labelKey="user.dark_mode_enable"
            @checked={{@controller.enableDarkMode}}
          />
        </div>
      </div>
    {{/if}}

    <div class="control-group text-size" data-setting-name="user-text-size">
      <label for="text-size-selector" class="control-label">{{i18n
          "user.text_size.title"
        }}</label>
      <div class="controls">
        <ComboBox
          @id="text-size-selector"
          @valueProperty="value"
          @content={{@controller.textSizes}}
          @value={{@controller.textSize}}
          @onChange={{@controller.selectTextSize}}
        />
      </div>
      {{#if @controller.showTextSetDefault}}
        <div class="controls">
          <PreferenceCheckbox
            @labelKey="user.text_size_default_on_all_devices"
            @checked={{@controller.makeTextSizeDefault}}
          />
        </div>
      {{/if}}
    </div>

    {{#if @controller.siteSettings.allow_user_locale}}
      <div class="control-group pref-locale" data-setting-name="user-locale">
        <label for="locale-selector" class="control-label">{{i18n
            "user.locale.title"
          }}</label>
        <div class="controls">
          <ComboBox
            @id="locale-selector"
            @valueProperty="value"
            @langProperty="value"
            @content={{@controller.availableLocales}}
            @value={{@controller.model.locale}}
            @onChange={{fn (mut @controller.model.locale)}}
            @options={{hash filterable=true none="user.locale.default"}}
          />
        </div>
        <div class="instructions">
          {{i18n "user.locale.instructions"}}
        </div>
      </div>
    {{/if}}

    <div class="control-group home" data-setting-name="user-home">
      <label for="home-selector" class="control-label">{{i18n
          "user.home"
        }}</label>
      <div class="controls">
        <ComboBox
          @id="home-selector"
          @content={{@controller.userSelectableHome}}
          @valueProperty="value"
          @value={{@controller.homepageId}}
          @onChange={{fn (mut @controller.model.user_option.homepage_id)}}
        />
      </div>
    </div>

    <fieldset
      class="control-group other"
      data-setting-name="user-other-settings"
    >
      <legend class="control-label">{{i18n "user.other_settings"}}</legend>

      <PreferenceCheckbox
        @labelKey="user.external_links_in_new_tab"
        @checked={{@controller.model.user_option.external_links_in_new_tab}}
        data-setting-name="user-external-links"
        class="pref-external-links"
      />
      <PreferenceCheckbox
        @labelKey="user.enable_quoting"
        @checked={{@controller.model.user_option.enable_quoting}}
        data-setting-name="user-enable-quoting"
        class="pref-enable-quoting"
      />
      <PreferenceCheckbox
        @labelKey="user.enable_smart_lists"
        @checked={{@controller.model.user_option.enable_smart_lists}}
        data-setting-name="user-enable-smart-lists"
        class="pref-enable-smart-lists"
      />
      <PreferenceCheckbox
        @labelKey="user.enable_defer"
        @checked={{@controller.model.user_option.enable_defer}}
        data-setting-name="user-enable-defer"
        class="pref-defer-unread"
      />
      {{#if @controller.siteSettings.automatically_unpin_topics}}
        <PreferenceCheckbox
          @labelKey="user.automatically_unpin_topics"
          @checked={{@controller.model.user_option.automatically_unpin_topics}}
          data-setting-name="user-auto-unpin"
          class="pref-auto-unpin"
        />
      {{/if}}
      <PreferenceCheckbox
        @labelKey="user.dynamic_favicon"
        @checked={{@controller.model.user_option.dynamic_favicon}}
        data-setting-name="user-dynamic-favicon"
        class="pref-dynamic-favicon"
      />
      <div
        class="controls controls-dropdown pref-page-title"
        data-setting-name="user-page-title"
      >
        <label for="user-title-count-mode">{{i18n
            "user.title_count_mode.title"
          }}</label>
        <ComboBox
          @valueProperty="value"
          @content={{@controller.titleCountModes}}
          @value={{@controller.model.user_option.title_count_mode}}
          @id="user-title-count-mode"
          @onChange={{fn (mut @controller.model.user_option.title_count_mode)}}
        />
      </div>
      <div
        class="controls controls-dropdown pref-bookmark-after-notification"
        data-setting-name="user-bookmark-after-notification"
      >
        <label for="bookmark-after-notification-mode">{{i18n
            "user.bookmark_after_notification.title"
          }}</label>
        <ComboBox
          @valueProperty="value"
          @content={{@controller.bookmarkAfterNotificationModes}}
          @value={{@controller.model.user_option.bookmark_auto_delete_preference}}
          @id="bookmark-after-notification-mode"
          @onChange={{fn
            (mut @controller.model.user_option.bookmark_auto_delete_preference)
          }}
        />
      </div>
      <PreferenceCheckbox
        @labelKey="user.skip_new_user_tips.description"
        @checked={{@controller.model.user_option.skip_new_user_tips}}
        data-setting-name="user-new-user-tips"
        class="pref-new-user-tips"
      />
      {{#if @controller.site.user_tips}}
        <DButton
          @action={{@controller.resetSeenUserTips}}
          data-setting-name="user-reset-seen-user-tips"
          class="btn-default pref-reset-seen-user-tips"
        >{{i18n "user.reset_seen_user_tips"}}</DButton>
      {{/if}}
    </fieldset>

    <span>
      <PluginOutlet
        @name="user-preferences-interface"
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
