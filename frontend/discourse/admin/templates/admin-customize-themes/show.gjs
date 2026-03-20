import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import DButton from "discourse/ui-kit/d-button";
import DTextField from "discourse/ui-kit/d-text-field";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="show-current-style admin-customize-themes-show">
    <div class="back-to-themes-and-components">
      <LinkTo
        @route={{if
          @controller.model.component
          "adminConfig.customize.components"
          "adminConfig.customize.themes"
        }}
      >
        {{dIcon "angle-left"}}
        {{i18n
          (if
            @controller.model.component
            "admin.config_areas.themes_and_components.components.back"
            "admin.config_areas.themes_and_components.themes.back"
          )
        }}
      </LinkTo>
    </div>

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
          <DTextField @value={{@controller.model.name}} @autofocus="true" />
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
        <DButton
          @action={{@controller.startEditingName}}
          class="btn-transparent title-button"
          role="heading"
          aria-level="2"
          aria-label="Edit theme name: {{@controller.model.name}}"
        >
          <span>{{@controller.model.name}}</span>
          {{#unless @controller.model.system}}
            {{dIcon "pencil" class="inline-icon"}}
          {{/unless}}
        </DButton>
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
            }}{{dIcon "link"}}</a>
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
            {{dIcon "triangle-exclamation"}}
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
          {{dFormatDate
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
            <DUserLink @user={{@controller.model.disabled_by}}>
              {{dAvatar @controller.model.disabled_by imageSize="tiny"}}
              {{@controller.model.disabled_by.username}}
            </DUserLink>
            {{dFormatDate @controller.model.disabled_at leaveAgo="true"}}
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

      <div class="metadata control-unit remote-theme-metadata">
        {{#if @controller.model.remote_theme}}
          {{#if @controller.model.remote_theme.remote_url}}
            {{#if @controller.sourceIsHttp}}
              <a class="remote-url" href={{@controller.remoteThemeLink}}>{{i18n
                  "admin.customize.theme.source_url"
                }}{{dIcon "link"}}</a>
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
            >{{i18n "admin.customize.theme.about_theme"}}{{dIcon "link"}}</a>
          {{/if}}

          {{#if @controller.model.remote_theme.license_url}}
            <a
              class="url license-url"
              href={{@controller.model.remote_theme.license_url}}
            >{{i18n "admin.customize.theme.license"}}{{dIcon "link"}}</a>
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

          {{#if @controller.model.remote_theme.is_git}}
            <div class="alert alert-info remote-theme-edits">
              {{trustHTML
                (i18n
                  "admin.customize.theme.remote_theme_edits"
                  repoURL=@controller.remoteThemeLink
                )
              }}
            </div>

            {{#if @controller.showRemoteError}}
              <div class="error-message">
                {{dIcon "triangle-exclamation"}}
                {{i18n "admin.customize.theme.repo_unreachable"}}
              </div>
              <div class="raw-error">
                <code>{{@controller.model.remoteError}}</code>
              </div>
            {{/if}}
          {{/if}}
        {{/if}}
      </div>

      {{#if @controller.model.system}}
        <div class="alert alert-info system-theme-info">
          {{i18n "admin.customize.theme.built_in_description"}}
        </div>
      {{/if}}

      {{outlet}}
    {{/if}}
  </div>
</template>
