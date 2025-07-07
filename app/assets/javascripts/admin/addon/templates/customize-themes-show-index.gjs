import { fn, hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import { and, not } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import UserLink from "discourse/components/user-link";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import formatUsername from "discourse/helpers/format-username";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import InlineEditCheckbox from "admin/components/inline-edit-checkbox";
import ThemeSettingEditor from "admin/components/theme-setting-editor";
import ThemeSettingRelativesSelector from "admin/components/theme-setting-relatives-selector";
import ThemeTranslation from "admin/components/theme-translation";
import ColorPalettes from "select-kit/components/color-palettes";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <div class="metadata control-unit">
      {{#if @controller.model.remote_theme}}
        <div class="control-unit">
          {{#if @controller.model.remote_theme.is_git}}
            {{#if @controller.model.remote_theme.commits_behind}}
              <DButton
                @action={{@controller.updateToLatest}}
                @icon="download"
                @label="admin.customize.theme.update_to_latest"
                class="btn-primary"
              />
            {{else}}
              <DButton
                @action={{@controller.checkForThemeUpdates}}
                @icon="arrows-rotate"
                @label="admin.customize.theme.check_for_updates"
                class="btn-default"
              />
            {{/if}}

            <span class="status-message">
              {{#if @controller.updatingRemote}}
                {{i18n "admin.customize.theme.updating"}}
              {{else}}
                {{#if @controller.model.remote_theme.commits_behind}}
                  {{#if @controller.hasOverwrittenHistory}}
                    {{i18n "admin.customize.theme.has_overwritten_history"}}
                  {{else}}
                    {{i18n
                      "admin.customize.theme.commits_behind"
                      count=@controller.model.remote_theme.commits_behind
                    }}
                  {{/if}}
                  {{#if @controller.model.remote_theme.github_diff_link}}
                    <a href={{@controller.model.remote_theme.github_diff_link}}>
                      {{i18n "admin.customize.theme.compare_commits"}}
                    </a>
                  {{/if}}
                {{else}}
                  {{#unless @controller.showRemoteError}}
                    {{i18n "admin.customize.theme.up_to_date"}}
                    {{formatDate
                      @controller.model.remote_theme.updated_at
                      leaveAgo="true"
                    }}
                  {{/unless}}
                {{/if}}
              {{/if}}
            </span>
          {{else}}
            <span class="status-message">
              {{icon "circle-info"}}
              {{i18n "admin.customize.theme.imported_from_archive"}}
            </span>
          {{/if}}
        </div>
      {{else if (not @controller.model.system)}}
        <span class="heading created-by">{{i18n
            "admin.customize.theme.creator"
          }}</span>
        <span>
          <UserLink @user={{@controller.model.user}}>
            {{formatUsername @controller.model.user.username}}
          </UserLink>
        </span>
      {{/if}}
    </div>

    {{#if @controller.showCheckboxes}}
      <div class="control-unit">
        {{#unless @controller.model.component}}
          <InlineEditCheckbox
            @action={{@controller.applyDefault}}
            @labelKey="admin.customize.theme.is_default"
            @checked={{@controller.model.default}}
            @modelId={{@controller.model.id}}
          />
          <InlineEditCheckbox
            @action={{@controller.applyUserSelectable}}
            @labelKey="admin.customize.theme.user_selectable"
            @checked={{@controller.model.user_selectable}}
            @modelId={{@controller.model.id}}
          />
        {{/unless}}
        {{#if @controller.model.remote_theme}}
          <InlineEditCheckbox
            @action={{@controller.applyAutoUpdateable}}
            @labelKey="admin.customize.theme.auto_update"
            @checked={{@controller.model.auto_update}}
            @modelId={{@controller.model.id}}
          />
        {{/if}}
      </div>
    {{/if}}

    {{#unless @controller.model.component}}
      {{#unless @controller.siteSettings.use_overhauled_theme_color_palette}}
        <section
          class="form-horizontal theme settings control-unit theme-settings__color-scheme"
        >
          <div class="row setting">
            <div class="setting-label">
              {{i18n "admin.customize.theme.color_scheme"}}
            </div>

            <div class="setting-value">
              <div class="color-palette-input-group">
                <ColorPalettes
                  @content={{@controller.colorSchemes}}
                  @value={{@controller.colorSchemeId}}
                  @icon="paintbrush"
                  @options={{hash filterable=true}}
                />
                {{#if @controller.colorSchemeId}}
                  <DButton
                    @icon="pencil"
                    @action={{@controller.editColorScheme}}
                    @title="admin.customize.theme.edit_color_scheme"
                  />
                {{/if}}
              </div>

              <div class="desc">{{i18n
                  "admin.customize.theme.color_scheme_select"
                }}</div>
            </div>

            <div class="setting-controls">
              {{#if @controller.colorSchemeChanged}}
                <DButton
                  @action={{@controller.changeScheme}}
                  @icon="check"
                  class="ok submit-edit"
                />
                <DButton
                  @action={{@controller.cancelChangeScheme}}
                  @icon="xmark"
                  class="cancel cancel-edit"
                />
              {{/if}}
            </div>
          </div>
        </section>
      {{/unless}}
    {{/unless}}

    {{#if @controller.model.component}}
      <section
        class="form-horizontal theme settings control-unit relative-theme-selector parent-themes-setting"
      >
        <div class="row setting">
          <ThemeSettingRelativesSelector
            @setting={{@controller.relativesSelectorSettingsForComponent}}
            @model={{@controller.model}}
            class="theme-setting"
          />
        </div>
      </section>
    {{else}}
      <section
        class="form-horizontal theme settings control-unit relative-theme-selector included-components-setting"
      >
        <div class="row setting">
          <PluginOutlet
            @name="admin-customize-theme-included-components-setting"
            @outletArgs={{lazyHash
              setting=@controller.relativesSelectorSettingsForTheme
              model=@controller.model
            }}
          >
            <ThemeSettingRelativesSelector
              @setting={{@controller.relativesSelectorSettingsForTheme}}
              @model={{@controller.model}}
              class="theme-setting"
            />
          </PluginOutlet>
        </div>
      </section>
    {{/if}}

    {{#unless @controller.model.system}}
      {{#unless @controller.model.remote_theme.is_git}}
        <div class="control-unit">
          <div class="mini-title">{{i18n
              "admin.customize.theme.css_html"
            }}</div>
          {{#if @controller.model.hasEditedFields}}
            <div class="description">{{i18n
                "admin.customize.theme.custom_sections"
              }}</div>
            <ul>
              {{#each @controller.editedFieldsFormatted as |field|}}
                <li>{{field}}</li>
              {{/each}}
            </ul>
          {{else}}
            <div class="description">
              {{i18n "admin.customize.theme.edit_css_html_help"}}
            </div>
          {{/if}}

          <DButton
            @action={{@controller.editTheme}}
            @label="admin.customize.theme.edit_css_html"
            class="btn-default edit edit-code"
          />
        </div>
      {{/unless}}

      <div class="control-unit">
        <div class="mini-title">{{i18n "admin.customize.theme.uploads"}}</div>
        {{#if @controller.model.uploads}}
          <ul class="removable-list">
            {{#each @controller.model.uploads as |upload|}}
              <li>
                {{! template-lint-disable no-unnecessary-curly-strings }}
                {{! workaround for https://github.com/typed-ember/glint/issues/840 }}
                <span class="col">{{"$"}}{{upload.name}}:
                  <a
                    href={{upload.url}}
                    rel="noopener noreferrer"
                    target="_blank"
                  >{{upload.filename}}</a></span>
                <span class="col">
                  <DButton
                    @action={{fn @controller.removeUpload upload}}
                    @icon="xmark"
                    class="second btn-default btn-default cancel-edit"
                  />
                </span>
              </li>
            {{/each}}
          </ul>
        {{else}}
          <div class="description">{{i18n
              "admin.customize.theme.no_uploads"
            }}</div>
        {{/if}}
        <DButton
          @action={{@controller.addUploadModal}}
          @icon="plus"
          @label="admin.customize.theme.add"
          class="btn-default upload"
        />
      </div>
    {{/unless}}

    {{#if (and @controller.extraFiles.length (not @controller.model.system))}}
      <div class="control-unit extra-files">
        <div class="mini-title">{{i18n
            "admin.customize.theme.extra_files"
          }}</div>
        {{! template-lint-disable no-nested-interactive }}
        <details>
          <summary>
            {{#if @controller.model.remote_theme}}
              {{i18n "admin.customize.theme.extra_files_remote"}}
            {{else}}
              {{i18n "admin.customize.theme.extra_files_upload"}}
            {{/if}}
          </summary>
          <ul>
            {{#each @controller.extraFiles as |extraFile|}}
              <li>{{extraFile.name}}</li>
            {{/each}}
          </ul>
        </details>
      </div>
    {{/if}}

    {{#if @controller.hasSettings}}
      <div class="control-unit theme-settings">
        <div class="mini-title">{{i18n
            "admin.customize.theme.theme_settings"
          }}</div>
        <p><i>{{i18n
              "admin.customize.theme.overriden_settings_explanation"
            }}</i></p>
        <section class="form-horizontal theme settings control-unit">
          {{#each @controller.settings as |setting|}}
            <ThemeSettingEditor
              @setting={{setting}}
              @model={{@controller.model}}
              class="theme-setting control-unit"
            />
          {{/each}}
        </section>
      </div>
    {{/if}}

    {{#if @controller.hasTranslations}}
      <div class="control-unit">
        <div class="translation-selector-container">
          <span class="mini-title">
            {{i18n "admin.customize.theme.theme_translations"}}
          </span>
          <ComboBox
            @valueProperty="value"
            @content={{@controller.availableLocales}}
            @value={{@controller.locale}}
            @onChange={{@controller.updateLocale}}
            @options={{hash filterable=true}}
            class="translation-selector"
          />
        </div>
        <ConditionalLoadingSpinner
          @condition={{@controller.model.loadingTranslations}}
        >
          <section
            class="form-horizontal theme settings translations control-unit"
          >

            {{#each @controller.translations as |translation|}}
              <ThemeTranslation
                @translation={{translation}}
                @model={{@controller.model}}
                class="theme-translation"
              />
            {{/each}}
          </section>
        </ConditionalLoadingSpinner>
      </div>
    {{/if}}

    <PluginOutlet
      @name="admin-customize-theme-before-controls"
      @outletArgs={{lazyHash theme=@controller.model}}
    />
    <div class="theme-controls">
      <a
        href={{@controller.previewUrl}}
        title={{i18n "admin.customize.explain_preview"}}
        rel="noopener noreferrer"
        target="_blank"
        class="btn btn-default"
      >{{icon "desktop"}}{{i18n "admin.customize.theme.preview"}}</a>
      {{#unless @controller.model.system}}
        <a
          class="btn btn-default export"
          rel="noopener noreferrer"
          target="_blank"
          href={{@controller.downloadUrl}}
        >{{icon "download"}} {{i18n "admin.export_json.button_text"}}</a>
      {{/unless}}

      {{#if @controller.showConvert}}
        <DButton
          @action={{@controller.switchType}}
          @label="admin.customize.theme.convert"
          @icon={{@controller.convertIcon}}
          @title={{@controller.convertTooltip}}
          class="btn-default btn-normal"
        />
      {{/if}}

      {{#if @controller.model.component}}
        {{#if @controller.model.enabled}}
          <DButton
            @action={{@controller.disableComponent}}
            @icon="ban"
            @label="admin.customize.theme.disable"
            class="btn-default"
          />
        {{else}}
          <DButton
            @action={{@controller.enableComponent}}
            @icon="check"
            @label="admin.customize.theme.enable"
            class="btn-default"
          />
        {{/if}}
      {{/if}}
      {{#if (and @controller.hasSettings (not @controller.model.system))}}
        <DButton
          @action={{@controller.showThemeSettingsEditor}}
          @label="admin.customize.theme.settings_editor"
          @icon="pencil"
          @title="admin.customize.theme.settings_editor"
          class="btn-default btn-normal"
        />
      {{/if}}
      {{#unless @controller.model.system}}
        <DButton
          @action={{@controller.destroyTheme}}
          @label="admin.customize.delete"
          @icon="trash-can"
          class="btn-danger delete"
        />
      {{/unless}}
    </div>
  </template>
);
