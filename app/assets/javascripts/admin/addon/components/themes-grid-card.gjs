import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import ThemesGridPlaceholder from "./themes-grid-placeholder";

// NOTE (martin): We will need to revisit and improve this component
// over time.
//
// Much of the existing theme logic in /admin/customize/themes has old patterns
// and technical debt, so anything copied from there to here is subject
// to change as we improve this incrementally.
export default class ThemeCard extends Component {
  @service siteSettings;
  @service toasts;

  get themeRouteModels() {
    return ["themes", this.args.theme.id];
  }

  get childrenString() {
    return this.args.theme.childThemes.reduce((acc, theme, idx) => {
      if (idx === this.args.theme.childThemes.length - 1) {
        return acc + theme.name;
      } else {
        return acc + theme.name + ", ";
      }
    }, "");
  }

  get themePreviewUrl() {
    return `/admin/themes/${this.args.theme.id}/preview`;
  }

  // NOTE: inspired by -> https://github.com/discourse/discourse/blob/24caa36eef826bcdaed88aebfa7df154413fb349/app/assets/javascripts/admin/addon/controllers/admin-customize-themes-show.js#L366
  //
  // Will also need some cleanup when refactoring other theme code.
  @action
  async setDefault() {
    let oldDefaultThemeId;

    this.args.theme.set("default", true);
    this.args.allThemes.forEach((theme) => {
      if (theme.id !== this.args.theme.id) {
        if (theme.get("default")) {
          oldDefaultThemeId = theme.id;
        }

        theme.set("default", !this.args.theme.get("default"));
      }
    });

    const changesSaved = await this.args.theme.saveChanges("default");
    if (!changesSaved) {
      this.args.allThemes
        .find((theme) => theme.id === oldDefaultThemeId)
        .set("default", true);
      this.args.theme.set("default", false);
      return;
    }

    this.toasts.success({
      data: {
        message: I18n.t("admin.customize.theme.set_default_success", {
          theme: this.args.theme.name,
        }),
      },
      duration: 2000,
    });
  }

  <template>
    <AdminConfigAreaCard
      class={{concatClass "theme-card" (if @theme.default "-active")}}
      @translatedHeading={{@theme.name}}
    >
      <:content>
        <div class="theme-card__image-wrapper">
          {{#if @theme.screenshot_url}}
            <img
              class="theme-card__image"
              src={{@theme.screenshot_url}}
              alt={{@theme.name}}
            />
          {{else}}
            <ThemesGridPlaceholder @theme={{@theme}} />
          {{/if}}
        </div>
        <div class="theme-card__content">
          {{#if @theme.description}}
            <p class="theme-card__description">{{@theme.description}}</p>
          {{/if}}
          {{#if @theme.childThemes}}
            <span class="theme-card__components">{{i18n
                "admin.customize.theme.components"
              }}:
              {{htmlSafe this.childrenString}}</span>
          {{/if}}
        </div>
        <div class="theme-card__footer">
          <DButton
            @action={{this.setDefault}}
            @preventFocus={{true}}
            @icon={{if @theme.default "far-check-square" "far-square"}}
            @class={{concatClass
              "theme-card__button"
              (if @theme.default "btn-primary" "btn-default")
            }}
            @translatedLabel={{i18n
              (if
                @theme.default
                "admin.customize.theme.default_theme"
                "admin.customize.theme.set_default_theme"
              )
            }}
            @disabled={{@theme.default}}
          />
          {{#if @theme.isPendingUpdates}}
            <DButton
              @route="adminCustomizeThemes.show"
              @routeModels={{this.themeRouteModels}}
              @icon="sync"
              @class="btn btn-flat theme-card__button"
              @title="admin.customize.theme.updates_available_tooltip"
              @preventFocus={{true}}
            />
          {{else}}
            {{#if @theme.isBroken}}
              <DButton
                @route="adminCustomizeThemes.show"
                @routeModels={{this.themeRouteModels}}
                @icon="exclamation-circle"
                @class="btn btn-flat theme-card__button broken-indicator"
                @title="admin.customize.theme.broken_theme_tooltip"
                @preventFocus={{true}}
              />
            {{/if}}
            {{#unless @theme.enabled}}
              <DButton
                @route="adminCustomizeThemes.show"
                @routeModels={{this.themeRouteModels}}
                @icon="ban"
                @class="btn btn-flat theme-card__button broken-indicator light-grey-icon"
                @title="admin.customize.theme.disabled_component_tooltip"
                @preventFocus={{true}}
              />
            {{/unless}}
          {{/if}}
          <div class="theme-card__footer-actions">
            <a
              href={{this.themePreviewUrl}}
              title={{i18n "admin.customize.explain_preview"}}
              rel="noopener noreferrer"
              target="_blank"
              class="btn btn-flat theme-card__button"
            >{{icon "eye"}}</a>
            <DButton
              @route="adminCustomizeThemes.show"
              @routeModels={{this.themeRouteModels}}
              @icon="cog"
              @class="btn-flat theme-card__button"
              @preventFocus={{true}}
            />
          </div>
        </div>
      </:content>
    </AdminConfigAreaCard>
  </template>
}
