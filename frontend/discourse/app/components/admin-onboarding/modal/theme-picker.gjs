import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import ThemeCardPreview from "discourse/components/theme-card-preview";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import {
  FOUNDATION_THEME_ID,
  HORIZON_THEME_ID,
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
  @service designWizard;

  @tracked themes = [];
  @tracked loading = true;
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
      this.selectedTheme =
        this.themes.find((theme) => theme.id === this.designWizard.themeId) ||
        this.themes.find((theme) => theme.default) ||
        null;
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  get nextDisabled() {
    return !this.selectedTheme;
  }

  @action
  selectTheme(theme) {
    this.selectedTheme = theme;
  }

  @action
  next() {
    if (this.nextDisabled) {
      return;
    }

    const themeId = this.selectedTheme.id;
    this.args.closeModal();
    this.designWizard.completeThemeStep(themeId);
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
              @action={{this.next}}
              @label="admin_onboarding_banner.design_wizard.next"
              @disabled={{this.nextDisabled}}
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
