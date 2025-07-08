import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminConfigAreaCard from "admin/components/admin-config-area-card";
import DMenu from "float-kit/components/d-menu";
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

  @tracked isUpdating = false;

  get themeCardClasses() {
    return [
      "theme-card",
      this.args.theme.get("default") ? "-active" : "",
      this.isUpdating ? "--updating" : "",
      dasherize(this.args.theme.name),
    ].join(" ");
  }

  get themeRouteModels() {
    return ["themes", this.args.theme.id];
  }

  get themePreviewUrl() {
    return `/admin/themes/${this.args.theme.id}/preview`;
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  // NOTE: inspired by -> https://github.com/discourse/discourse/blob/24caa36eef826bcdaed88aebfa7df154413fb349/app/assets/javascripts/admin/addon/controllers/admin-customize-themes-show.js#L366
  //
  // Will also need some cleanup when refactoring other theme code.
  @action
  async setDefault() {
    let oldDefaultThemeId;

    this.args.theme.set("default", true);
    this.dMenu.close();
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
        message: i18n("admin.customize.theme.set_default_success", {
          theme: this.args.theme.name,
        }),
      },
      duration: "short",
    });

    window.location.reload();
  }

  @action
  async toggleUserSelectable() {
    let oldUserSelectable = this.args.theme.user_selectable;

    this.args.theme.set("user_selectable", !oldUserSelectable);
    this.dMenu.close();

    const changesSaved = await this.args.theme.saveChanges("user_selectable");
    if (!changesSaved) {
      this.args.theme.set("user_selectable", oldUserSelectable);
      return;
    }

    this.toasts.success({
      data: {
        message: i18n("admin.customize.theme.setting_was_saved"),
      },
      duration: "short",
    });
  }

  @action
  updateTheme() {
    if (this.isUpdating) {
      return;
    }

    this.isUpdating = true;
    this.args.theme
      .updateToLatest()
      .then(() => {
        this.toasts.success({
          data: {
            message: i18n("admin.customize.theme.update_success", {
              theme: this.args.theme.name,
            }),
          },
          duration: "short",
        });
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.isUpdating = false;
      });
  }

  <template>
    <AdminConfigAreaCard class={{this.themeCardClasses}}>
      <:content>
        {{#if @theme.default}}
          <span
            class="theme-card__badge --active"
            title={{i18n "admin.customize.theme.default_theme"}}
          >
            {{i18n "admin.customize.theme.default"}}
          </span>
        {{/if}}

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
          <div class="theme-card__title">{{@theme.name}}</div>
          {{#if @theme.description}}
            <p class="theme-card__description">{{@theme.description}}</p>
          {{/if}}
        </div>
        <div class="theme-card__footer">
          <div class="theme-card__badges">
            {{#if @theme.isPendingUpdates}}
              <span
                title={{i18n "admin.customize.theme.updates_available_tooltip"}}
                class="theme-card__badge"
              >{{icon "arrows-rotate"}}
                {{i18n "admin.customize.theme.update_available"}}</span>
            {{/if}}

            {{#if @theme.user_selectable}}
              <span
                title={{i18n "admin.customize.theme.user_selectable"}}
                class="theme-card__badge --selectable"
              >{{icon "user-check"}}
                {{i18n
                  "admin.customize.theme.user_selectable_badge_label"
                }}</span>
            {{/if}}
          </div>

          <div class="theme-card__controls">
            <DButton
              @translatedLabel={{i18n "admin.customize.theme.edit"}}
              @route="adminCustomizeThemes.show"
              @routeModels={{this.themeRouteModels}}
              class="btn-secondary theme-card__button edit"
              @preventFocus={{true}}
            />

            <div class="theme-card__footer-actions">
              <DMenu
                @identifier="theme-card__footer-menu"
                @triggerClass="theme-card__footer-menu btn-flat"
                @onRegisterApi={{this.onRegisterApi}}
                @modalForMobile={{true}}
                @icon="ellipsis"
                @triggers={{array "click"}}
              >
                <:content>
                  <DropdownMenu as |dropdown|>
                    {{! TODO: Jordan
                      solutions for broken, disabled states }}
                    <dropdown.item>
                      <DButton
                        @action={{this.setDefault}}
                        @preventFocus={{true}}
                        @icon={{if @theme.default "star" "far-star"}}
                        class="theme-card__button set-active"
                        @translatedLabel={{i18n
                          (if
                            @theme.default
                            "admin.customize.theme.default_theme"
                            "admin.customize.theme.set_default_theme"
                          )
                        }}
                        @disabled={{@theme.default}}
                      />
                    </dropdown.item>
                    {{#if @theme.isPendingUpdates}}
                      <dropdown.item>
                        <DButton
                          @action={{this.updateTheme}}
                          @icon="cloud-arrow-down"
                          class="theme-card__button update"
                          @preventFocus={{true}}
                          @translatedLabel={{i18n
                            "admin.customize.theme.update_to_latest"
                          }}
                        />
                      </dropdown.item>
                    {{/if}}
                    <dropdown.item>
                      <DButton
                        @action={{this.toggleUserSelectable}}
                        @preventFocus={{true}}
                        @icon={{if
                          @theme.user_selectable
                          "user-xmark"
                          "user-check"
                        }}
                        class="theme-card__button set-selectable"
                        @translatedLabel={{i18n
                          (if
                            @theme.user_selectable
                            "admin.customize.theme.user_selectable_unavailable_button_label"
                            "admin.customize.theme.user_selectable_button_label"
                          )
                        }}
                      />
                    </dropdown.item>
                    <dropdown.item>
                      <a
                        href={{this.themePreviewUrl}}
                        title={{i18n "admin.customize.explain_preview"}}
                        rel="noopener noreferrer"
                        target="_blank"
                        class="btn btn-transparent theme-card__button preview"
                      >{{icon "eye"}}
                        {{i18n "admin.customize.theme.preview"}}</a>
                    </dropdown.item>
                  </DropdownMenu>
                </:content>
              </DMenu>
            </div>
          </div>
        </div>
      </:content>
    </AdminConfigAreaCard>
  </template>
}
