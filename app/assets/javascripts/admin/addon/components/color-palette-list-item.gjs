import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { not } from "truth-helpers";
import ColorPalettePreview from "discourse/components/color-palette-preview";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import DButtonTooltip from "float-kit/components/d-button-tooltip";
import DMenu from "float-kit/components/d-menu";
import DTooltip from "float-kit/components/d-tooltip";

export default class ColorPaletteListItem extends Component {
  @service router;

  @tracked isLoading = false;

  get isBuiltInDefault() {
    return this.args.scheme?.is_builtin_default || false;
  }

  get canEdit() {
    return !this.isBuiltInDefault && this.args.scheme?.id;
  }

  get isThemePalette() {
    return this.args.scheme?.theme_id;
  }

  get editButtonLabel() {
    return this.isThemePalette && !this.isBuiltInDefault
      ? "admin.customize.colors.view"
      : "admin.customize.colors.edit";
  }

  get canDelete() {
    return !this.isBuiltInDefault && !this.args.scheme?.theme_id;
  }

  get showSetAsDefault() {
    if (this.isBuiltInDefault) {
      return this.args.defaultTheme?.color_scheme_id;
    }
    return true;
  }

  get isDefaultLight() {
    if (this.isBuiltInDefault) {
      return this.args.defaultTheme && !this.args.defaultTheme.color_scheme_id;
    }
    return (
      this.args.defaultTheme &&
      this.args.isDefaultThemeLightColorScheme(this.args.scheme)
    );
  }

  get isDefaultDark() {
    if (this.isBuiltInDefault) {
      return (
        this.args.defaultDarkTheme &&
        !this.args.defaultDarkTheme.color_scheme_id
      );
    }
    return (
      this.args.defaultTheme &&
      this.args.isDefaultThemeDarkColorScheme(this.args.scheme)
    );
  }

  get editUrl() {
    if (!this.canEdit) {
      return null;
    }
    return this.router.urlFor(
      "adminConfig.colorPalettes.show",
      this.args.scheme.id
    );
  }

  @bind
  setAsDefaultLabel(mode) {
    const themeName = this.args.defaultTheme?.name || "Default";

    return i18n(`admin.customize.colors.set_default_${mode}`, {
      theme: themeName,
    });
  }

  @action
  async handleAsyncAction(asyncFn, ...args) {
    this.dMenu.close();
    this.isLoading = true;
    try {
      await asyncFn(...args);
    } finally {
      this.isLoading = false;
    }
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    <li
      class="admin-config-area-card color-palette"
      data-palette-id={{@scheme.id}}
    >
      <div class="color-palette__container">
        <ColorPalettePreview
          class="color-palette__preview"
          @scheme={{@scheme}}
        />

        <div class="color-palette__details">
          {{#if this.editUrl}}
            <h3><a href={{this.editUrl}}>{{@scheme.description}}</a></h3>
          {{else}}
            <h3>{{@scheme.description}}</h3>
          {{/if}}
          <div class="color-palette__theme-link">
            {{#if @scheme.theme_id}}
              <LinkTo
                @route="adminCustomizeThemes.show"
                @models={{array "themes" @scheme.theme_id}}
              >
                {{icon "link"}}
                {{@scheme.theme_name}}
              </LinkTo>
            {{/if}}
          </div>

          <div class="color-palette__badges">
            {{#if this.isDefaultLight}}
              <span
                title={{i18n
                  "admin.customize.colors.default_light_badge.title"
                }}
                class="theme-card__badge --default"
              >
                {{icon "sun"}}
                {{i18n "admin.customize.colors.default_light_badge.text"}}
              </span>
            {{/if}}

            {{#if this.isDefaultDark}}
              <span
                title={{i18n "admin.customize.colors.default_dark_badge.title"}}
                class="theme-card__badge --default"
              >
                {{icon "moon"}}
                {{i18n "admin.customize.colors.default_dark_badge.text"}}
              </span>
            {{/if}}

            {{#if @scheme.user_selectable}}
              <span
                title={{i18n "admin.customize.theme.user_selectable"}}
                class="theme-card__badge --selectable"
              >
                {{icon "user-check"}}
                {{i18n "admin.customize.theme.user_selectable_badge_label"}}
              </span>
            {{/if}}
          </div>
        </div>

        <div class="color-palette__controls">
          <DButtonTooltip>
            <:button>
              <DButton
                @route="adminConfig.colorPalettes.show"
                @routeModels={{array @scheme.id}}
                @label={{this.editButtonLabel}}
                class="btn-secondary"
                @disabled={{not this.canEdit}}
              />
            </:button>
            <:tooltip>
              {{#unless this.canEdit}}
                <DTooltip
                  @icon="circle-info"
                  @content={{i18n "admin.customize.colors.system_palette"}}
                />
              {{/unless}}
            </:tooltip>
          </DButtonTooltip>

          {{#if this.showSetAsDefault}}
            <DMenu
              @triggerClass="btn-flat"
              @modalForMobile={{true}}
              @icon="ellipsis"
              @onRegisterApi={{this.onRegisterApi}}
              @isLoading={{this.isLoading}}
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  {{#unless this.isBuiltInDefault}}
                    <dropdown.item>
                      <DButton
                        @action={{fn
                          this.handleAsyncAction
                          @toggleUserSelectable
                          @scheme
                        }}
                        @icon={{if
                          @scheme.user_selectable
                          "user-xmark"
                          "user-check"
                        }}
                        @label={{if
                          @scheme.user_selectable
                          "admin.customize.theme.user_selectable_unavailable_button_label"
                          "admin.customize.theme.user_selectable_button_label"
                        }}
                        class="btn-transparent"
                      />
                    </dropdown.item>
                  {{/unless}}

                  <dropdown.item>
                    <DButton
                      @action={{fn
                        this.handleAsyncAction
                        @setAsDefaultThemePalette
                        @scheme
                        "light"
                      }}
                      @icon="far-star"
                      @translatedLabel={{fn this.setAsDefaultLabel "light"}}
                      class="btn-transparent btn-palette-default"
                      disabled={{this.isDefaultLight}}
                    />
                  </dropdown.item>
                  <dropdown.item>
                    <DButton
                      @action={{fn
                        this.handleAsyncAction
                        @setAsDefaultThemePalette
                        @scheme
                        "dark"
                      }}
                      @icon="star"
                      @translatedLabel={{fn this.setAsDefaultLabel "dark"}}
                      class="btn-transparent btn-palette-default"
                      disabled={{this.isDefaultDark}}
                    />
                  </dropdown.item>

                  {{#if this.canDelete}}
                    <dropdown.item>
                      <DButton
                        @action={{fn
                          this.handleAsyncAction
                          @deleteColorScheme
                          @scheme
                        }}
                        @icon="trash-can"
                        @label="admin.customize.delete"
                        class="btn-transparent btn-danger"
                      />
                    </dropdown.item>
                  {{/if}}
                </DropdownMenu>
              </:content>
            </DMenu>
          {{/if}}
        </div>
      </div>
    </li>
  </template>
}
