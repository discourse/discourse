import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import ThemesGridPlaceholder from "./themes-grid-placeholder";

// NOTE (martin): Much of the JS code in this component is placeholder code. Much
// of the existing theme logic in /admin/customize/themes has old patterns
// and technical debt, so anything copied from there to here is subject
// to change as we improve this incrementally.
export default class ThemeCard extends Component {
  @service siteSettings;
  @service toasts;

  // NOTE: These 3 shouldn't need @computed, if we convert
  // theme to a pure JS class with @tracked properties we
  // won't need to do this.
  @computed("args.theme.default")
  get setDefaultButtonIcon() {
    return this.args.theme.default ? "far-check-square" : "far-square";
  }

  @computed("args.theme.default")
  get setDefaultButtonTitle() {
    return this.args.theme.default
      ? "admin.customize.theme.default_theme"
      : "admin.customize.theme.set_default_theme";
  }

  @computed("args.theme.default")
  get setDefaultButtonClasses() {
    return this.args.theme.default
      ? "btn-primary theme-card__button"
      : "btn-default theme-card__button";
  }

  @computed(
    "args.theme.default",
    "args.theme.isBroken",
    "args.theme.enabled",
    "args.theme.isPendingUpdates"
  )
  get themeCardClasses() {
    return this.args.theme.isBroken
      ? "--broken"
      : !this.args.theme.enabled
      ? "--disabled"
      : this.args.theme.isPendingUpdates
      ? "--updates"
      : this.args.theme.default
      ? "--active"
      : "";
  }

  get imageAlt() {
    return this.args.theme.name;
  }

  get hasScreenshot() {
    return this.args.theme.screenshot ? true : false;
  }

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

  @action
  showPreview() {
    // TODO (martin)
    // bring admin to theme preview of site
  }

  // NOTE: inspired by -> https://github.com/discourse/discourse/blob/24caa36eef826bcdaed88aebfa7df154413fb349/app/assets/javascripts/admin/addon/controllers/admin-customize-themes-show.js#L366
  //
  // Will also need some cleanup when refactoring other theme code.
  @action
  async setDefault() {
    this.args.theme.set("default", true);
    this.args.theme.saveChanges("default").then(() => {
      this.args.allThemes.forEach((theme) => {
        if (theme.id !== this.args.theme.id) {
          theme.set("default", !this.args.theme.get("default"));
        }
      });
      this.toasts.success({
        data: {
          message: I18n.t("admin.customize.theme.set_default_success", {
            theme: this.args.theme.name,
          }),
        },
        duration: 2000,
      });
    });
  }

  @action
  async handleSubmit(event) {
    this.args.theme.set("user_selectable", event.target.checked);
    this.args.theme.saveChanges("user_selectable");
  }

  <template>
    <AdminConfigAreaCard
      class={{concatClass "theme-card" this.themeCardClasses}}
    >
      <:optionalCustomHeading>
        {{@theme.name}}
        <span class="theme-card__icons">
          {{#if @theme.isPendingUpdates}}
            <DButton
              @route="adminCustomizeThemes.show"
              @routeModels={{this.themeRouteModels}}
              @icon="sync"
              @class="btn-flat theme-card__button"
              @preventFocus={{true}}
            />
          {{else}}
            {{#if @theme.isBroken}}
              {{icon
                "exclamation-circle"
                class="broken-indicator"
                title="admin.customize.theme.broken_theme_tooltip"
              }}
            {{/if}}
            {{#unless @theme.enabled}}
              {{icon
                "ban"
                class="light-grey-icon"
                title="admin.customize.theme.disabled_component_tooltip"
              }}
            {{/unless}}
          {{/if}}
        </span>
      </:optionalCustomHeading>
      <:optionalAction>
        <Input
          @type="checkbox"
          @checked={{@theme.user_selectable}}
          id="user-select-theme-{{@theme.id}}"
          onclick={{this.handleSubmit}}
        />
        <label
          class="theme-card__checkbox-label"
          for="user-select-theme-{{@theme.id}}"
        >
          {{i18n "admin.config_areas.look_and_feel.themes.user_selectable"}}
        </label>
      </:optionalAction>
      <:content>
        <div class="theme-card__image-wrapper">
          {{#if this.hasScreenshot}}
            <img
              class="theme-card__image"
              src={{htmlSafe @theme.screenshot}}
              alt={{this.imageAlt}}
            />
          {{else}}
            <ThemesGridPlaceholder @theme={{@theme}} />
          {{/if}}
        </div>
        <div class="theme-card__content">
          <p class="theme-card__description">{{@theme.description}}</p>
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
            @icon={{this.setDefaultButtonIcon}}
            @class={{this.setDefaultButtonClasses}}
            @translatedLabel={{i18n this.setDefaultButtonTitle}}
            @disabled={{@theme.default}}
          />
          <div class="theme-card-footer__actions">
            <DButton
              @action={{this.showPreview}}
              @icon="eye"
              @class="btn-flat theme-card__button"
              @preventFocus={{true}}
            />
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
