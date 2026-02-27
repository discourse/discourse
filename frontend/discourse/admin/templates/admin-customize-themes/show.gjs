import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import InlineEditCheckbox from "discourse/admin/components/inline-edit-checkbox";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import TextField from "discourse/components/text-field";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import formatUsername from "discourse/helpers/format-username";
import lazyHash from "discourse/helpers/lazy-hash";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default <template>
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
  <div class="show-current-style admin-customize-themes-show">

    <span>
      <PluginOutlet
        @name="admin-customize-themes-show-top"
        @connectorTagName="div"
        @outletArgs={{lazyHash theme=@controller.model}}
      />
    </span>

    <div class="title admin-customize-themes-show__title">
      {{#if @controller.editingName}}
        <div class="container-edit-title">
          <TextField @value={{@controller.model.name}} @autofocus="true" />
          <DButton
            @action={{@controller.finishedEditingName}}
            @icon="check"
            class="btn-primary btn-small submit-edit"
          />
          <DButton
            @action={{@controller.cancelEditingName}}
            @icon="xmark"
            class="btn-default btn-small cancel-edit"
          />
        </div>
      {{else}}
        {{! template-lint-disable no-invalid-interactive }}

        <h1
          {{on "click" @controller.startEditingName}}
          class="title-button"
          aria-level="2"
          aria-label="Edit theme name: {{@controller.model.name}}"
        >
          <span>{{@controller.model.name}}</span>
          {{#unless @controller.model.system}}
            {{icon "pencil" class="inline-icon"}}
          {{/unless}}
        </h1>
      {{/if}}
      {{#if @controller.model.description}}
        <span class="theme-description">{{@controller.model.description}}</span>
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
      {{#if @controller.model.system}}
        <div class="alert alert-info system-theme-info">
          {{i18n "admin.customize.theme.built_in_description"}}
        </div>
      {{/if}}
      <div
        class="metadata control-unit remote-theme-metadata admin-config-area-card"
      >
        {{#if @controller.model.remote_theme}}
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

          {{#if @controller.model.remote_theme.authors}}<span
              class="authors"
            ><span class="heading">{{i18n
                  "admin.customize.theme.authors"
                }}</span>
              {{@controller.model.remote_theme.authors}}</span>{{/if}}
          {{#if @controller.model.remote_theme.remote_url}}
            <span class="theme-url"><span class="heading">{{i18n
                  "admin.customize.theme.source_url"
                }}</span>
              {{#if @controller.sourceIsHttp}}
                <a class="git-name" href={{@controller.remoteThemeLink}}>
                  {{@controller.remoteThemeLink}}</a>
              {{else}}
                <span class="git-name">
                  {{@controller.model.remote_theme.remote_url}}
                  {{#if
                    @controller.model.remote_theme.branch
                  }}/{{@controller.model.remote_theme.branch}}
                  {{/if}}
                </span>
              {{/if}}
            </span>
          {{/if}}

          {{#if @controller.model.remote_theme.branch}}<span
              class="branch"
            ><span class="heading">{{i18n
                  "admin.customize.theme.branch"
                }}</span>
              <span
                class="git-name"
              >{{@controller.model.remote_theme.branch}}</span></span>{{/if}}

          {{#if @controller.model.remote_theme.theme_version}}<span
              class="version"
            ><span class="heading">{{i18n
                  "admin.customize.theme.version"
                }}</span>
              {{@controller.model.remote_theme.theme_version}}</span>{{/if}}
        {{/if}}

        {{#if @controller.model.remote_theme}}
          <div class="remote-theme-actions">
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

              <DButton
                @action={{@controller.changeSource}}
                @icon="rotate"
                @label="admin.customize.theme.change_source.button"
                class="btn-default"
              />
            {{else}}
              <span class="status-message">
                {{icon "circle-info"}}
                {{i18n "admin.customize.theme.imported_from_archive"}}
              </span>
            {{/if}}
          </div>
        {{else if (not @controller.model.system)}}
          <span class="created-by">
            <span class="heading">{{i18n
                "admin.customize.theme.creator"
              }}</span>
            <span>
              <UserLink @user={{@controller.model.user}}>
                {{formatUsername @controller.model.user.username}}
              </UserLink>
            </span>
          </span>
        {{/if}}
        {{#if @controller.showCheckboxes}}
          <div class="inline-checkboxes">
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
      </div>

      {{outlet}}
    {{/if}}
  </div>
</template>
