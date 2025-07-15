import Component from "@glimmer/component";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";
import { not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { getColorSchemeStyles } from "admin/lib/color-transformations";
import DMenu from "float-kit/components/d-menu";

export default class ColorSchemeListItem extends Component {
  get isBuiltInDefault() {
    return this.args.scheme === null;
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
    return htmlSafe(getColorSchemeStyles(this.args.scheme));
  }

  @action
  setDefault() {
    this.args.toggleUserSelectable(this.args.scheme);
    this.dMenu.close();
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    <li style={{this.styles}} class="admin-config-area-card color-palette">
      <div class="color-palette__container">
        <div class="color-palette__details">
          {{#if this.isBuiltInDefault}}
            <h3>
              {{i18n "admin.customize.theme.default_light_scheme"}}
            </h3>
            <div class="color-palette__theme-link"></div>
          {{else}}
            <h3>{{@scheme.description}}</h3>
            <div class="color-palette__theme-link">
              {{#if @scheme.theme_id}}
                <LinkTo
                  @route="adminCustomizeThemes.show"
                  @models={{array "themes" @scheme.theme_id}}
                >
                  {{icon "paintbrush"}}
                  {{@scheme.theme_name}}
                </LinkTo>
              {{/if}}
            </div>
          {{/if}}

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
          <DButton
            @route="adminCustomize.colors-show"
            @routeModels={{array @scheme.id}}
            @label="admin.customize.colors.edit"
            class="btn-secondary"
            disabled={{not this.canEdit}}
          />

          {{#if this.showSetAsDefault}}
            <DMenu
              @triggerClass="btn-flat"
              @modalForMobile={{true}}
              @icon="ellipsis"
              @triggers={{array "click"}}
              @onRegisterApi={{this.onRegisterApi}}
            >
              <:content>
                <DropdownMenu as |dropdown|>
                  {{#unless this.isBuiltInDefault}}
                    <dropdown.item>
                      <DButton
                        @action={{this.setDefault}}
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
                        @setAsDefaultThemePalette
                        (if this.isBuiltInDefault null @scheme)
                      }}
                      @icon="star"
                      @label="admin.customize.colors.set_default"
                      class="btn-transparent"
                      disabled={{this.isActive}}
                    />
                  </dropdown.item>

                  {{#if this.canDelete}}
                    <dropdown.item>
                      <DButton
                        @action={{fn @deleteColorScheme @scheme}}
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
