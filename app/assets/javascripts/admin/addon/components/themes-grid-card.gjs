import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";
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
    ].join(" ");
  }

  get themeRouteModels() {
    return ["themes", this.args.theme.id];
  }

  get themePreviewUrl() {
    return `/admin/themes/${this.args.theme.id}/preview`;
  }

  get footerActionIcon() {
    return this.args.theme.isPendingUpdates ? "sync" : "ellipsis-h";
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
            message: I18n.t("admin.customize.theme.update_success", {
              theme: this.args.theme.name,
            }),
          },
          duration: 2000,
        });
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.isUpdating = false;
      });
  }

  <template>
    <AdminConfigAreaCard
      class={{this.themeCardClasses}}
      @translatedHeading={{@theme.name}}
    >
      <:content>
        {{#if @theme.isPendingUpdates}}
          <span
            title={{i18n "admin.customize.theme.updates_available_tooltip"}}
            class="theme-card__update-available"
          >{{icon "info-circle"}}</span>
        {{/if}}
        <div class="theme-card__image-wrapper">
          {{#if @theme.screenshot}}
            <img
              class="theme-card__image"
              src={{htmlSafe @theme.screenshot}}
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
        </div>
        <div class="theme-card__footer">
          <DButton
            @translatedLabel={{i18n "admin.customize.theme.edit"}}
            @route="adminCustomizeThemes.show"
            @routeModels={{this.themeRouteModels}}
            @class="btn-primary theme-card__button"
            @preventFocus={{true}}
          />

          <div class="theme-card__footer-actions">
            <DMenu
              @identifier="theme-card__footer-menu"
              @triggerClass="theme-card__footer-menu btn-flat"
              @modalForMobile={{true}}
              @icon={{this.footerActionIcon}}
              @label={{if
                this.isUpdating
                (i18n "admin.customize.theme.updating")
                ""
              }}
              @triggers={{array "click"}}
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  {{#if @theme.isPendingUpdates}}
                    <dropdown.item>
                      <DButton
                        @action={{this.updateTheme}}
                        @icon="download"
                        @class="theme-card__button -update"
                        @preventFocus={{true}}
                        @translatedLabel={{i18n
                          "admin.customize.theme.update_to_latest"
                        }}
                      />
                    </dropdown.item>
                  {{/if}}
                  {{! TODO: Jordan
                    solutions for broken, disabled states }}
                  <dropdown.item>
                    <DButton
                      @action={{this.setDefault}}
                      @preventFocus={{true}}
                      @icon={{if
                        @theme.default
                        "far-check-square"
                        "far-square"
                      }}
                      @class="theme-card__button"
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
                  <dropdown.item>
                    <a
                      href={{this.themePreviewUrl}}
                      title={{i18n "admin.customize.explain_preview"}}
                      rel="noopener noreferrer"
                      target="_blank"
                      class="btn btn-transparent theme-card__button"
                    >{{icon "eye"}} {{i18n "admin.customize.theme.preview"}}</a>
                  </dropdown.item>
                </DropdownMenu>
              </:content>
            </DMenu>
          </div>
        </div>
      </:content>
    </AdminConfigAreaCard>
  </template>
}
