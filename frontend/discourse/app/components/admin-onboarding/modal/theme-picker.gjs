import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import PluginOutlet from "discourse/components/plugin-outlet";
import ThemeCardPreview from "discourse/components/theme-card-preview";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import {
  FOUNDATION_THEME_ID,
  HORIZON_THEME_ID,
  setLocalTheme,
} from "discourse/lib/theme-selector";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const ALLOWED_THEME_IDS = [FOUNDATION_THEME_ID, HORIZON_THEME_ID];

const ThemeCard = <template>
  <div
    class="theme-picker-modal__card {{if @isSelected '--selected'}}"
    {{on "click" (fn @onSelect @theme)}}
    role="button"
  >
    {{#if @isSelected}}
      <span class="theme-picker-modal__enabled-badge">
        {{dIcon "check"}}
        {{i18n "admin_onboarding_banner.select_theme.enabled"}}
      </span>
    {{/if}}
    <ThemeCardPreview @theme={{@theme}} />
  </div>
</template>;

export default class ThemePickerModal extends Component {
  @tracked themes = [];
  @tracked loading = true;
  @tracked saving = false;
  @tracked selectedTheme = null;

  constructor() {
    super(...arguments);
    this.loadThemes();
  }

  async loadThemes() {
    try {
      const result = await ajax("/admin/themes.json");
      this.themes = result.themes.filter((theme) =>
        ALLOWED_THEME_IDS.includes(theme.id)
      );
      this.selectedTheme = this.themes.find((t) => t.default) || null;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  get applyDisabled() {
    return !this.selectedTheme || this.saving;
  }

  @action
  selectTheme(theme) {
    this.selectedTheme = theme;
  }

  @action
  async applyTheme() {
    if (this.applyDisabled) {
      return;
    }

    if (this.selectedTheme.default) {
      await this.args.model?.onThemeSelected?.();
      this.args.closeModal();
      return;
    }

    this.saving = true;

    try {
      await ajax(`/admin/themes/${this.selectedTheme.id}.json`, {
        type: "PUT",
        data: { theme: { default: true } },
      });

      setLocalTheme([], 0);

      await this.args.model?.onThemeSelected?.();
      window.location.reload();
    } catch (error) {
      this.saving = false;
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      class="theme-picker-modal --max"
      @title={{i18n "admin_onboarding_banner.select_theme.modal_title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        {{#if this.loading}}
          <div class="theme-picker-modal__loading">
            <div class="spinner"></div>
          </div>
        {{else}}
          <div class="theme-picker-modal__themes">
            {{#each this.themes as |theme|}}
              <ThemeCard
                @theme={{theme}}
                @isSelected={{if
                  this.selectedTheme
                  (eq this.selectedTheme.id theme.id)
                  false
                }}
                @onSelect={{this.selectTheme}}
              />
            {{/each}}
          </div>
          <div class="theme-picker-modal__footer">
            <DButton
              @action={{this.applyTheme}}
              @translatedLabel={{if
                this.saving
                (i18n "admin_onboarding_banner.select_theme.applying_theme")
                (i18n "admin_onboarding_banner.select_theme.use_theme")
              }}
              @disabled={{this.applyDisabled}}
              @isLoading={{this.saving}}
              class="btn-primary"
            />
          </div>
          <PluginOutlet @name="theme-picker-modal-below-themes">
            <p class="theme-picker-modal__browse-all">
              <a href={{getURL "/admin/config/customize/themes"}}>
                {{i18n "admin_onboarding_banner.select_theme.browse_all"}}
              </a>
            </p>
          </PluginOutlet>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
