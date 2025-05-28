import { fn, hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import { not, or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import TextField from "discourse/components/text-field";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import formatUsername from "discourse/helpers/format-username";
import htmlSafe from "discourse/helpers/html-safe";
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
    {{#if
      (or
        @controller.model.component
        (not @controller.siteSettings.use_overhauled_theme_color_palette)
      )
    }}
      <div class="back-to-themes-and-components">
        <LinkTo
          @route={{if
            @controller.model.component
            "adminConfig.customize.components"
            "adminConfig.customize.themes"
          }}
        >
          {{icon "angle-left"}}
          {{i18n
            (if
              @controller.model.component
              "admin.config_areas.themes_and_components.components.back"
              "admin.config_areas.themes_and_components.themes.back"
            )
          }}
        </LinkTo>
      </div>
    {{/if}}

    <div class="show-current-style">
      <span>
        <PluginOutlet
          @name="admin-customize-themes-show-top"
          @connectorTagName="div"
          @outletArgs={{lazyHash theme=@controller.model}}
        />
      </span>

      <div class="title">
        {{#if @controller.editingName}}
          <TextField @value={{@controller.model.name}} @autofocus="true" />
          <DButton
            @action={{@controller.finishedEditingName}}
            @icon="check"
            class="btn-primary btn-small submit-edit"
          />
          <DButton
            @action={{@controller.cancelEditingName}}
            @icon="xmark"
            class="btn-small cancel-edit"
          />
        {{else}}
          <span>{{@controller.model.name}}</span>
          <DButton
            @action={{@controller.startEditingName}}
            @icon="pencil"
            class="btn-small"
          />
        {{/if}}
      </div>

      <PluginOutlet
        @name="admin-customize-theme-before-errors"
        @outletArgs={{lazyHash theme=@controller.model}}
      />

      {{#each @controller.model.errors as |error|}}
        <div class="alert alert-error">{{error}}</div>
      {{/each}}

      {{#if @controller.finishInstall}}
        <div class="control-unit">
          {{#if @controller.sourceIsHttp}}
            <a class="remote-url" href={{@controller.remoteThemeLink}}>{{i18n
                "admin.customize.theme.source_url"
              }}{{icon "link"}}</a>
          {{else}}
            <div class="remote-url">
              <code>{{@controller.model.remote_theme.remote_url}}</code>
              {{#if @controller.model.remote_theme.branch}}
                (<code>{{@controller.model.remote_theme.branch}}</code>)
              {{/if}}
            </div>
          {{/if}}

          {{#if @controller.showRemoteError}}
            <div class="error-message">
              {{icon "triangle-exclamation"}}
              {{i18n "admin.customize.theme.repo_unreachable"}}
            </div>
            <div class="raw-error">
              <code>{{@controller.model.remoteError}}</code>
            </div>
          {{/if}}

          <DButton
            @action={{@controller.updateToLatest}}
            @icon="download"
            @label="admin.customize.theme.finish_install"
            class="btn-primary finish-install"
          />
          <DButton
            @action={{@controller.destroyTheme}}
            @label="admin.customize.delete"
            @icon="trash-can"
            class="btn-danger"
          />

          <span class="status-message">
            {{i18n "admin.customize.theme.last_attempt"}}
            {{formatDate
              @controller.model.remote_theme.updated_at
              leaveAgo="true"
            }}
          </span>
        </div>
      {{else}}
        {{#unless @controller.model.supported}}
          <div class="alert alert-error">
            {{i18n "admin.customize.theme.required_version.error"}}
            {{#if @controller.model.remote_theme.minimum_discourse_version}}
              {{i18n
                "admin.customize.theme.required_version.minimum"
                version=@controller.model.remote_theme.minimum_discourse_version
              }}
            {{/if}}
            {{#if @controller.model.remote_theme.maximum_discourse_version}}
              {{i18n
                "admin.customize.theme.required_version.maximum"
                version=@controller.model.remote_theme.maximum_discourse_version
              }}
            {{/if}}
          </div>
        {{/unless}}

        {{#unless @controller.model.enabled}}
          <div class="alert alert-error">
            {{#if @controller.model.disabled_by}}
              {{i18n "admin.customize.theme.disabled_by"}}
              <UserLink @user={{@controller.model.disabled_by}}>
                {{avatar @controller.model.disabled_by imageSize="tiny"}}
                {{@controller.model.disabled_by.username}}
              </UserLink>
              {{formatDate @controller.model.disabled_at leaveAgo="true"}}
            {{else}}
              {{i18n "admin.customize.theme.disabled"}}
            {{/if}}
            <DButton
              @action={{@controller.enableComponent}}
              @icon="check"
              @label="admin.customize.theme.enable"
              class="btn-default"
            />
          </div>
        {{/unless}}

        <div class="metadata control-unit">
          {{#if @controller.model.remote_theme}}
            {{#if @controller.model.remote_theme.remote_url}}
              {{#if @controller.sourceIsHttp}}
                <a
                  class="remote-url"
                  href={{@controller.remoteThemeLink}}
                >{{i18n "admin.customize.theme.source_url"}}{{icon "link"}}</a>
              {{else}}
                <div class="remote-url">
                  <code>{{@controller.model.remote_theme.remote_url}}</code>
                  {{#if @controller.model.remote_theme.branch}}
                    (<code>{{@controller.model.remote_theme.branch}}</code>)
                  {{/if}}
                </div>
              {{/if}}
            {{/if}}

            {{#if @controller.model.remote_theme.about_url}}
              <a
                class="url about-url"
                href={{@controller.model.remote_theme.about_url}}
              >{{i18n "admin.customize.theme.about_theme"}}{{icon "link"}}</a>
            {{/if}}

            {{#if @controller.model.remote_theme.license_url}}
              <a
                class="url license-url"
                href={{@controller.model.remote_theme.license_url}}
              >{{i18n "admin.customize.theme.license"}}{{icon "link"}}</a>
            {{/if}}

            {{#if @controller.model.description}}
              <span
                class="theme-description"
              >{{@controller.model.description}}</span>
            {{/if}}

            {{#if @controller.model.remote_theme.authors}}<span
                class="authors"
              ><span class="heading">{{i18n
                    "admin.customize.theme.authors"
                  }}</span>
                {{@controller.model.remote_theme.authors}}</span>{{/if}}

            {{#if @controller.model.remote_theme.theme_version}}<span
                class="version"
              ><span class="heading">{{i18n
                    "admin.customize.theme.version"
                  }}</span>
                {{@controller.model.remote_theme.theme_version}}</span>{{/if}}

            <div class="control-unit">
              {{#if @controller.model.remote_theme.is_git}}
                <div class="alert alert-info">
                  {{htmlSafe
                    (i18n
                      "admin.customize.theme.remote_theme_edits"
                      repoURL=@controller.remoteThemeLink
                    )
                  }}
                </div>

                {{#if @controller.showRemoteError}}
                  <div class="error-message">
                    {{icon "triangle-exclamation"}}
                    {{i18n "admin.customize.theme.repo_unreachable"}}
                  </div>
                  <div class="raw-error">
                    <code>{{@controller.model.remoteError}}</code>
                  </div>
                {{/if}}

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
                        <a
                          href={{@controller.model.remote_theme.github_diff_link}}
                        >
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
          {{else}}
            <span class="heading">{{i18n
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
          {{#unless
            @controller.siteSettings.use_overhauled_theme_color_palette
          }}
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
          <section class="form-horizontal theme settings control-unit">
            <div class="row setting">
              <ThemeSettingRelativesSelector
                @setting={{@controller.relativesSelectorSettingsForComponent}}
                @model={{@controller.model}}
                class="theme-setting"
              />
            </div>
          </section>
        {{else}}
          <section class="form-horizontal theme settings control-unit">
            <div class="row setting">
              <ThemeSettingRelativesSelector
                @setting={{@controller.relativesSelectorSettingsForTheme}}
                @model={{@controller.model}}
                class="theme-setting"
              />
            </div>
          </section>
        {{/if}}

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
              class="btn-default edit"
            />
          </div>

          <div class="control-unit">
            <div class="mini-title">{{i18n
                "admin.customize.theme.uploads"
              }}</div>
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
              class="btn-default"
            />
          </div>
        {{/unless}}

        {{#if @controller.extraFiles.length}}
          <div class="control-unit">
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
          <div class="control-unit">
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
          <a
            class="btn btn-default export"
            rel="noopener noreferrer"
            target="_blank"
            href={{@controller.downloadUrl}}
          >{{icon "download"}} {{i18n "admin.export_json.button_text"}}</a>

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
          {{#if @controller.hasSettings}}
            <DButton
              @action={{@controller.showThemeSettingsEditor}}
              @label="admin.customize.theme.settings_editor"
              @icon="pencil"
              @title="admin.customize.theme.settings_editor"
              class="btn-default btn-normal"
            />
          {{/if}}
          <DButton
            @action={{@controller.destroyTheme}}
            @label="admin.customize.delete"
            @icon="trash-can"
            class="btn-danger"
          />
        </div>
      {{/if}}
    </div>
  </template>
);
