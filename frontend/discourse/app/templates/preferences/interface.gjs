import { fn, hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import lazyHash from "discourse/helpers/lazy-hash";
import ColorPalettePicker from "discourse/select-kit/components/color-palette-picker";
import ComboBox from "discourse/select-kit/components/combo-box";
import MultiSelect from "discourse/select-kit/components/multi-select";
import DButton from "discourse/ui-kit/d-button";
import DSaveControls from "discourse/ui-kit/d-save-controls";
import { i18n } from "discourse-i18n";

export default <template>
  <span>
    <PluginOutlet
      @connectorTagName="div"
      @name="user-preferences-interface-top"
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
            @checked={{@controller.makeThemeDefault}}
            @labelKey="user.theme_default_on_all_devices"
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
        {{#if @controller.showLightColorSchemeSelector}}
          <div class="control-subgroup light-color-scheme">
            <div class="instructions">{{i18n
                "user.color_schemes.regular"
              }}</div>
            <div class="controls">
              <ColorPalettePicker
                @content={{@controller.userSelectableColorSchemes}}
                @onChange={{@controller.loadColorScheme}}
                @value={{@controller.selectedColorSchemeId}}
              />
            </div>
          </div>
        {{/if}}
        {{#if @controller.showDarkColorSchemeSelector}}
          <div class="control-subgroup dark-color-scheme">
            <div class="instructions">{{i18n "user.color_schemes.dark"}}</div>
            <div class="controls">
              <ColorPalettePicker
                @content={{@controller.userSelectableDarkColorSchemes}}
                @onChange={{@controller.loadDarkColorScheme}}
                @value={{@controller.selectedDarkColorSchemeId}}
              />
            </div>
          </div>
        {{/if}}
        {{#if @controller.showInterfaceColorModeSelector}}
          <div class="control-subgroup interface-color-mode">
            <div class="instructions">{{i18n
                "user.color_schemes.interface_mode"
              }}</div>
            <div class="controls">
              <ComboBox
                @content={{@controller.interfaceColorModes}}
                @onChange={{@controller.selectColorMode}}
                @value={{@controller.selectedInterfaceColorMode}}
              />
            </div>
          </div>
        {{/if}}
      </div>
      {{#if @controller.previewingColorScheme}}
        {{#if @controller.previewingColorScheme}}
          <DButton
            class="btn-default btn-small undo-preview"
            @action={{@controller.undoColorSchemePreview}}
            @icon="arrow-rotate-left"
            @label="user.color_schemes.undo"
          />
        {{/if}}
        <div class="controls color-scheme-checkbox">
          <PreferenceCheckbox
            @checked={{@controller.makeColorSchemeDefault}}
            @labelKey="user.color_scheme_default_on_all_devices"
          />
        </div>
      {{/if}}
      {{#if @controller.showDarkColorSchemeSelector}}
        <div class="instructions">
          {{i18n "user.color_schemes.interface_mode_instructions"}}
        </div>
      {{/if}}
    </fieldset>
  {{/if}}

  <div class="control-group text-size" data-setting-name="user-text-size">
    <label class="control-label" for="text-size-selector">{{i18n
        "user.text_size.title"
      }}</label>
    <div class="controls">
      <ComboBox
        @content={{@controller.textSizes}}
        @id="text-size-selector"
        @onChange={{@controller.selectTextSize}}
        @value={{@controller.textSize}}
        @valueProperty="value"
      />
    </div>
    {{#if @controller.showTextSetDefault}}
      <div class="controls">
        <PreferenceCheckbox
          @checked={{@controller.makeTextSizeDefault}}
          @labelKey="user.text_size_default_on_all_devices"
        />
      </div>
    {{/if}}
  </div>

  {{#if @controller.siteSettings.allow_user_locale}}
    <div class="control-group pref-locale" data-setting-name="user-locale">
      <label class="control-label" for="locale-selector">{{i18n
          "user.locale.title"
        }}</label>
      <div class="controls">
        <ComboBox
          @content={{@controller.availableLocales}}
          @id="locale-selector"
          @langProperty="value"
          @onChange={{@controller.setInterfaceLanguage}}
          @options={{hash filterable=true none="user.locale.default"}}
          @value={{@controller.model.locale}}
          @valueProperty="value"
        />
      </div>
      <div class="instructions">
        {{i18n "user.locale.instructions"}}
      </div>
    </div>
  {{/if}}

  {{#if @controller.siteSettings.content_localization_enabled}}
    <fieldset
      class="control-group pref-content-languages"
      data-setting-name="user-content-languages"
    >
      <legend class="control-label">{{i18n
          "user.content_languages.title"
        }}</legend>
      <div class="controls controls-dropdown pref-understood-languages">
        <label for="understood-languages-selector">{{i18n
            "user.content_languages.understood"
          }}</label>
        <MultiSelect
          @content={{@controller.availableLocales}}
          @id="understood-languages-selector"
          @langProperty="value"
          @onChange={{@controller.setUnderstoodLanguages}}
          @options={{hash filterable=true}}
          @value={{@controller.understoodLanguages}}
          @valueProperty="value"
        />
        <div class="instructions">
          {{i18n "user.content_languages.understood_description"}}
        </div>
      </div>
      <PreferenceCheckbox
        class="pref-automatically-translate"
        data-setting-name="user-automatically-translate"
        @checked={{@controller.model.user_option.automatically_translate}}
        @labelKey="user.automatically_translate"
      />
    </fieldset>
  {{/if}}

  <div class="control-group home" data-setting-name="user-home">
    <label class="control-label" for="home-selector">{{i18n
        "user.home"
      }}</label>
    <div class="controls">
      <ComboBox
        @content={{@controller.userSelectableHome}}
        @id="home-selector"
        @onChange={{fn (mut @controller.model.user_option.homepage_id)}}
        @value={{@controller.homepageId}}
        @valueProperty="value"
      />
    </div>
  </div>

  <fieldset class="control-group other" data-setting-name="user-other-settings">
    <legend class="control-label">{{i18n "user.other_settings"}}</legend>

    <PreferenceCheckbox
      class="pref-external-links"
      data-setting-name="user-external-links"
      @checked={{@controller.model.user_option.external_links_in_new_tab}}
      @labelKey="user.external_links_in_new_tab"
    />
    <PreferenceCheckbox
      class="pref-enable-quoting"
      data-setting-name="user-enable-quoting"
      @checked={{@controller.model.user_option.enable_quoting}}
      @labelKey="user.enable_quoting"
    />
    <PreferenceCheckbox
      class="pref-enable-smart-lists"
      data-setting-name="user-enable-smart-lists"
      @checked={{@controller.model.user_option.enable_smart_lists}}
      @labelKey="user.enable_smart_lists"
    />
    {{#if @controller.siteSettings.automatically_unpin_topics}}
      <PreferenceCheckbox
        class="pref-auto-unpin"
        data-setting-name="user-auto-unpin"
        @checked={{@controller.model.user_option.automatically_unpin_topics}}
        @labelKey="user.automatically_unpin_topics"
      />
    {{/if}}
    <PreferenceCheckbox
      class="pref-dynamic-favicon"
      data-setting-name="user-dynamic-favicon"
      @checked={{@controller.model.user_option.dynamic_favicon}}
      @labelKey="user.dynamic_favicon"
    />
    <PreferenceCheckbox
      class="pref-enable-markdown-monospace-font"
      data-setting-name="user-enable-markdown-monospace-font"
      @checked={{@controller.model.user_option.enable_markdown_monospace_font}}
      @labelKey="user.enable_markdown_monospace_font"
    />
    <div
      class="controls controls-dropdown pref-page-title"
      data-setting-name="user-page-title"
    >
      <label for="user-title-count-mode">{{i18n
          "user.title_count_mode.title"
        }}</label>
      <ComboBox
        @content={{@controller.titleCountModes}}
        @id="user-title-count-mode"
        @onChange={{fn (mut @controller.model.user_option.title_count_mode)}}
        @value={{@controller.model.user_option.title_count_mode}}
        @valueProperty="value"
      />
    </div>
    <div
      class="controls controls-dropdown pref-send-shortcut"
      data-setting-name="user-send-shortcut"
    >
      <label for="user-send-shortcut">{{i18n
          "user.send_shortcut.title"
        }}</label>
      <ComboBox
        @content={{@controller.sendShortcutOptions}}
        @id="user-send-shortcut"
        @onChange={{fn (mut @controller.model.user_option.send_shortcut)}}
        @value={{@controller.model.user_option.send_shortcut}}
        @valueProperty="value"
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
        @content={{@controller.bookmarkAfterNotificationModes}}
        @id="bookmark-after-notification-mode"
        @onChange={{fn
          (mut @controller.model.user_option.bookmark_auto_delete_preference)
        }}
        @value={{@controller.model.user_option.bookmark_auto_delete_preference}}
        @valueProperty="value"
      />
    </div>
    <PreferenceCheckbox
      class="pref-new-user-tips"
      data-setting-name="user-new-user-tips"
      @checked={{@controller.model.user_option.skip_new_user_tips}}
      @labelKey="user.skip_new_user_tips.description"
    />
    {{#if @controller.site.user_tips}}
      <DButton
        class="btn-default pref-reset-seen-user-tips"
        data-setting-name="user-reset-seen-user-tips"
        @action={{@controller.resetSeenUserTips}}
      >{{i18n "user.reset_seen_user_tips"}}</DButton>
    {{/if}}
  </fieldset>

  <span>
    <PluginOutlet
      @connectorTagName="div"
      @name="user-preferences-interface"
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
</template>
