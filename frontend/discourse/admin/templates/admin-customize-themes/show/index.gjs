import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import InlineEditCheckbox from "discourse/admin/components/inline-edit-checkbox";
import ThemeSettingEditor from "discourse/admin/components/theme-setting-editor";
import ThemeSettingRelativesSelector from "discourse/admin/components/theme-setting-relatives-selector";
import ThemeSiteSettingEditor from "discourse/admin/components/theme-site-setting-editor";
import ThemeTranslation from "discourse/admin/components/theme-translation";
import PluginOutlet from "discourse/components/plugin-outlet";
import formatUsername from "discourse/helpers/format-username";
import lazyHash from "discourse/helpers/lazy-hash";
import getURL from "discourse/lib/get-url";
import ColorPalettePicker from "discourse/select-kit/components/color-palette-picker";
import ComboBox from "discourse/select-kit/components/combo-box";
import { and, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";
import DUserLink from "discourse/ui-kit/d-user-link";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="metadata control-unit">
    {{#if @controller.model.remote_theme}}
      <div class="control-unit">
        {{#if @controller.model.remote_theme.is_git}}
          {{#if @controller.model.remote_theme.commits_behind}}
            <DButton
              class="btn-primary"
              @action={{@controller.updateToLatest}}
              @icon="download"
              @label="admin.customize.theme.update_to_latest"
            />
          {{else}}
            <DButton
              class="btn-default"
              @action={{@controller.checkForThemeUpdates}}
              @icon="arrows-rotate"
              @label="admin.customize.theme.check_for_updates"
            />
          {{/if}}

          <DButton
            class="btn-default"
            @action={{@controller.changeSource}}
            @icon="code-branch"
            @label="admin.customize.theme.change_source.button"
          />

          <span class="status-message">
            {{#if @controller.updatingRemote}}
              {{i18n "admin.customize.theme.updating"}}
            {{else}}
              {{#if @controller.model.remote_theme.commits_behind}}
                {{#if @controller.hasOverwrittenHistory}}
                  {{i18n "admin.customize.theme.has_overwritten_history"}}
                {{else}}
                  {{#if @controller.displayRemoteBranch}}
                    <DInterpolatedTranslation
                      @key="admin.customize.theme.commits_behind_branch"
                      @options={{hash
                        count=@controller.model.remote_theme.commits_behind
                      }}
                      as |Placeholder|
                    >
                      <Placeholder @name="branch">
                        <code>{{@controller.displayRemoteBranch}}</code>
                      </Placeholder>
                    </DInterpolatedTranslation>
                  {{else}}
                    {{i18n
                      "admin.customize.theme.commits_behind"
                      count=@controller.model.remote_theme.commits_behind
                    }}
                  {{/if}}
                {{/if}}
                {{#if @controller.model.remote_theme.github_diff_link}}
                  <a href={{@controller.model.remote_theme.github_diff_link}}>
                    {{i18n "admin.customize.theme.compare_commits"}}
                  </a>
                {{/if}}
              {{else}}
                {{#unless @controller.showRemoteError}}
                  {{#if @controller.displayRemoteBranch}}
                    <DInterpolatedTranslation
                      @key="admin.customize.theme.up_to_date_branch"
                      as |Placeholder|
                    >
                      <Placeholder @name="branch">
                        <code>{{@controller.displayRemoteBranch}}</code>
                      </Placeholder>
                    </DInterpolatedTranslation>
                  {{else}}
                    {{i18n "admin.customize.theme.up_to_date"}}
                  {{/if}}
                  {{dFormatDate
                    @controller.model.remote_theme.updated_at
                    leaveAgo="true"
                  }}
                {{/unless}}
              {{/if}}
            {{/if}}
          </span>
        {{else}}
          <span class="status-message">
            {{dIcon "circle-info"}}
            {{i18n "admin.customize.theme.imported_from_archive"}}
          </span>
        {{/if}}
      </div>
    {{else if (not @controller.model.system)}}
      <span class="heading created-by">{{i18n
          "admin.customize.theme.creator"
        }}</span>
      <span>
        <DUserLink @user={{@controller.model.user}}>
          {{formatUsername @controller.model.user.username}}
        </DUserLink>
      </span>
    {{/if}}
  </div>

  {{#if @controller.showCheckboxes}}
    <div class="control-unit">
      {{#unless @controller.model.component}}
        <InlineEditCheckbox
          @action={{@controller.applyDefault}}
          @checked={{@controller.model.default}}
          @labelKey="admin.customize.theme.is_default"
          @modelId={{@controller.model.id}}
        />
        <InlineEditCheckbox
          @action={{@controller.applyUserSelectable}}
          @checked={{@controller.model.user_selectable}}
          @labelKey="admin.customize.theme.user_selectable"
          @modelId={{@controller.model.id}}
        />
      {{/unless}}
      {{#if @controller.model.remote_theme}}
        <InlineEditCheckbox
          @action={{@controller.applyAutoUpdateable}}
          @checked={{@controller.model.auto_update}}
          @labelKey="admin.customize.theme.auto_update"
          @modelId={{@controller.model.id}}
        />
      {{/if}}
    </div>
  {{/if}}

  {{#unless @controller.model.component}}
    {{#if @controller.showColorSchemePickers}}
      <section
        class="form-horizontal theme settings control-unit theme-settings__light-color-scheme"
      >
        <div class="row setting">
          <div class="setting-label">
            {{i18n "admin.customize.theme.color_scheme"}}
          </div>

          <div class="setting-value">
            <div class="color-palette-input-group">
              <ColorPalettePicker
                @content={{@controller.filteredColorSchemes}}
                @icon="paintbrush"
                @options={{hash
                  filterable=true
                  translatedNone=(unless
                    @controller.model.only_theme_color_schemes
                    (i18n "admin.customize.theme.default_light_scheme")
                  )
                }}
                @value={{@controller.colorSchemeId}}
              />
            </div>

            <div class="desc">{{i18n
                "admin.customize.theme.color_scheme_select"
              }}

              {{#if @controller.colorSchemeId}}
                <LinkTo
                  @model={{@controller.colorSchemeId}}
                  @route="adminConfig.colorPalettes.show"
                >
                  {{i18n "admin.customize.theme.edit_colors"}}
                </LinkTo>
              {{/if}}
            </div>
          </div>

          <div class="setting-controls">
            {{#if @controller.lightColorSchemeChanged}}
              <DButton
                class="ok submit-light-edit"
                @action={{@controller.changeLightScheme}}
                @icon="check"
              />
              <DButton
                class="cancel cancel-light-edit"
                @action={{@controller.cancelChangeLightScheme}}
                @icon="xmark"
              />
            {{/if}}
          </div>
        </div>
      </section>
      <section
        class="form-horizontal theme settings control-unit theme-settings__dark-color-scheme"
      >
        <div class="row setting">
          <div class="setting-label">
            {{i18n "admin.customize.theme.dark_color_scheme"}}
          </div>

          <div class="setting-value">
            <div class="color-palette-input-group">
              <ColorPalettePicker
                @content={{@controller.filteredColorSchemes}}
                @icon="paintbrush"
                @options={{hash
                  filterable=true
                  translatedNone=(unless
                    @controller.model.only_theme_color_schemes
                    (i18n "admin.customize.theme.default_light_scheme")
                  )
                }}
                @value={{@controller.darkColorSchemeId}}
              />
            </div>

            <div class="desc">
              {{i18n "admin.customize.theme.dark_color_scheme_select"}}

              {{#if @controller.darkColorSchemeId}}
                <LinkTo
                  @model={{@controller.darkColorSchemeId}}
                  @route="adminConfig.colorPalettes.show"
                >
                  {{i18n "admin.customize.theme.edit_colors"}}
                </LinkTo>
              {{/if}}
            </div>
          </div>
          <div class="setting-controls">
            {{#if @controller.darkColorSchemeChanged}}
              <DButton
                class="ok submit-dark-edit"
                @action={{@controller.changeDarkScheme}}
                @icon="check"
              />
              <DButton
                class="cancel cancel-dark-edit"
                @action={{@controller.cancelChangeDarkScheme}}
                @icon="xmark"
              />
            {{/if}}
          </div>
        </div>
      </section>
    {{/if}}
  {{/unless}}

  {{#if @controller.model.component}}
    <section
      class="form-horizontal theme settings control-unit relative-theme-selector parent-themes-setting"
    >
      <div class="row setting">
        <ThemeSettingRelativesSelector
          class="theme-setting"
          @model={{@controller.model}}
          @setting={{@controller.relativesSelectorSettingsForComponent}}
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
            class="theme-setting"
            @model={{@controller.model}}
            @setting={{@controller.relativesSelectorSettingsForTheme}}
          />
        </PluginOutlet>
      </div>
    </section>
  {{/if}}

  {{#unless
    (or @controller.model.system @controller.model.remote_theme.is_git)
  }}
    <div class="control-unit">
      <div class="mini-title">{{i18n "admin.customize.theme.css_html"}}</div>
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
        class="btn-default edit edit-code"
        @action={{@controller.editTheme}}
        @label="admin.customize.theme.edit_css_html"
      />
    </div>

    <div class="control-unit">
      <div class="mini-title">{{i18n "admin.customize.theme.uploads"}}</div>
      {{#if @controller.model.uploads}}
        <ul class="removable-list">
          {{#each @controller.model.uploads as |upload|}}
            <li>
              <span class="col">${{upload.name}}:
                <a
                  href={{upload.url}}
                  rel="noopener noreferrer"
                  target="_blank"
                >{{upload.filename}}</a></span>
              <span class="col">
                <DButton
                  class="second btn-default btn-default cancel-edit"
                  @action={{fn @controller.removeUpload upload}}
                  @icon="xmark"
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
        class="btn-default upload"
        @action={{@controller.addUploadModal}}
        @icon="plus"
        @label="admin.customize.theme.add"
      />
    </div>
  {{/unless}}

  {{#if (and @controller.extraFiles.length (not @controller.model.system))}}
    <div class="control-unit extra-files">
      <div class="mini-title">{{i18n "admin.customize.theme.extra_files"}}</div>

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
            <li>{{extraFile.file_path}}</li>
          {{/each}}
        </ul>
      </details>
    </div>
  {{/if}}

  {{#if @controller.hasThemeableSiteSettings}}
    <div class="control-unit">
      <div class="mini-title">{{i18n
          "admin.customize.theme.theme_site_settings"
        }}</div>
      <p><i>{{trustHTML
            (i18n
              "admin.customize.theme.overriden_site_settings_explanation"
              themeSiteSettingsConfigUrl=(getURL
                "/admin/config/customize/theme-site-settings"
              )
            )
          }}</i></p>
      <section
        class="form-horizontal theme settings theme-site-settings control-unit"
      >
        {{#each @controller.themeSiteSettings as |setting|}}
          <ThemeSiteSettingEditor
            class="theme-site-setting control-unit"
            @model={{@controller.model}}
            @setting={{setting}}
          />
        {{/each}}
      </section>
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
            class="theme-setting control-unit"
            @model={{@controller.model}}
            @setting={{setting}}
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
        <div class="translation-selector-controls">
          <PluginOutlet
            @name="admin-customize-theme-translation-selector"
            @outletArgs={{lazyHash
              theme=@controller.model
              locale=@controller.locale
            }}
          />
          <ComboBox
            class="translation-selector"
            @content={{@controller.availableLocales}}
            @onChange={{@controller.updateLocale}}
            @options={{hash filterable=true}}
            @value={{@controller.locale}}
            @valueProperty="value"
          />
        </div>
      </div>
      <DConditionalLoadingSpinner
        @condition={{@controller.model.loadingTranslations}}
      >
        <section
          class="form-horizontal theme settings translations control-unit"
        >

          {{#each @controller.translations as |translation|}}
            <ThemeTranslation
              class="theme-translation"
              @model={{@controller.model}}
              @translation={{translation}}
            />
          {{/each}}
        </section>
      </DConditionalLoadingSpinner>
    </div>
  {{/if}}

  <PluginOutlet
    @name="admin-customize-theme-before-controls"
    @outletArgs={{lazyHash theme=@controller.model}}
  />
  <div class="theme-controls">
    <a
      class="btn btn-default"
      href={{@controller.previewUrl}}
      rel="noopener noreferrer"
      target="_blank"
      title={{i18n "admin.customize.explain_preview"}}
    >{{dIcon "desktop"}}{{i18n "admin.customize.theme.preview"}}</a>
    {{#unless @controller.model.system}}
      <DButton
        class="btn-default export"
        @action={{@controller.exportAction}}
        @href={{@controller.downloadUrl}}
        @icon="download"
        @label="admin.export_json.button_text"
      />
    {{/unless}}

    {{#if @controller.showConvert}}
      <DButton
        class="btn-default btn-normal"
        @action={{@controller.switchType}}
        @icon="rotate"
        @label="admin.customize.theme.convert"
        @title={{@controller.convertTooltip}}
      />
    {{/if}}

    {{#if @controller.model.component}}
      {{#if @controller.model.enabled}}
        <DButton
          class="btn-default"
          @action={{@controller.disableComponent}}
          @icon="ban"
          @label="admin.customize.theme.disable"
        />
      {{else}}
        <DButton
          class="btn-default"
          @action={{@controller.enableComponent}}
          @icon="check"
          @label="admin.customize.theme.enable"
        />
      {{/if}}
    {{/if}}
    {{#if (and @controller.hasSettings (not @controller.model.system))}}
      <DButton
        class="btn-default btn-normal"
        @action={{@controller.showThemeSettingsEditor}}
        @icon="pencil"
        @label="admin.customize.theme.settings_editor"
        @title="admin.customize.theme.settings_editor"
      />
    {{/if}}
    {{#unless (or @controller.model.system @controller.model.default)}}
      <DButton
        class="btn-danger delete"
        @action={{@controller.destroyTheme}}
        @icon="trash-can"
        @label="admin.customize.delete"
      />
    {{/unless}}
  </div>
</template>
