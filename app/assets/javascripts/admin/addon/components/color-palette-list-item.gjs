import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import SvgSingleColorPalettePlaceholder from "admin/components/svg/single-color-palette-placeholder";
import { getColorSchemeStyles } from "admin/lib/color-transformations";
import DButtonTooltip from "float-kit/components/d-button-tooltip";
import DMenu from "float-kit/components/d-menu";
import DTooltip from "float-kit/components/d-tooltip";

export default class ColorPaletteListItem extends Component {
  @tracked isLoading = false;

  get isBuiltInDefault() {
    return this.args.scheme?.is_builtin_default || false;
  }

  get setAsDefaultLabel() {
    const themeName = this.args.defaultTheme?.name || "Default";

    return i18n("admin.customize.colors.set_default", {
      theme: themeName,
    });
  }

  get canEdit() {
    return !this.isBuiltInDefault && this.args.scheme?.id;
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

  get isActive() {
    if (this.isBuiltInDefault) {
      return this.args.defaultTheme && !this.args.defaultTheme.color_scheme_id;
    }
    return (
      this.args.defaultTheme &&
      this.args.isDefaultThemeColorScheme(this.args.scheme)
    );
  }

  get styles() {
    if (this.isBuiltInDefault) {
      return htmlSafe(
        "--primary-low--preview: #e9e9e9; --tertiary-low--preview: #d1f0ff;"
      );
    }

    // generate primary-low and tertiary-low
    const existingStyles = getColorSchemeStyles(this.args.scheme);

    // create variables from scheme.colors
    const colorVariables =
      this.args.scheme?.colors
        ?.map((color) => {
          let hex = color.hex || color.default_hex;

          if (hex && !hex.startsWith("#")) {
            hex = `#${hex}`;
          }
          return `--${color.name}--preview: ${hex}`;
        })
        .join("; ") || "";

    const allStyles = colorVariables
      ? `${existingStyles} ${colorVariables};`
      : existingStyles;

    return htmlSafe(allStyles);
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
      style={{this.styles}}
      class="admin-config-area-card color-palette"
      data-palette-id={{@scheme.id}}
    >
      <div class="color-palette__container">
        <div class="color-palette__preview">
          <SvgSingleColorPalettePlaceholder />
        </div>

        <div class="color-palette__details">
          <h3>{{@scheme.description}}</h3>
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

          {{#if this.isActive}}
            <span
              title={{i18n "admin.customize.colors.active_badge.title"}}
              class="theme-card__badge --active"
            >
              {{i18n "admin.customize.colors.active_badge.text"}}
            </span>
          {{/if}}
        </div>

        <div class="color-palette__controls">
          <DButtonTooltip>
            <:button>
              <DButton
                @route="adminCustomize.colors-show"
                @routeModels={{array @scheme.id}}
                @label="admin.customize.colors.edit"
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
              @triggers={{array "click"}}
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
                      }}
                      @icon="star"
                      @translatedLabel={{this.setAsDefaultLabel}}
                      class="btn-transparent btn-palette-default"
                      disabled={{this.isActive}}
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
