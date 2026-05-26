import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
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
  setLocalTheme,
} from "discourse/lib/theme-selector";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";

const ALLOWED_THEME_IDS = [FOUNDATION_THEME_ID, HORIZON_THEME_ID];

const ThemeCard = <template>
  <div class="theme-picker-modal__card {{if @theme.default '--active'}}">
    {{#if @theme.default}}
      <span class="theme-picker-modal__enabled-badge">
        {{dIcon "check"}}
        {{i18n "admin_onboarding_banner.select_theme.enabled"}}
      </span>
    {{/if}}
    <ThemeCardPreview @theme={{@theme}}>
      <:footer>
        <DButton
          @action={{fn @onSelect @theme}}
          @translatedLabel={{i18n
            "admin_onboarding_banner.select_theme.use_theme"
          }}
          class="btn-primary"
        />
      </:footer>
    </ThemeCardPreview>
  </div>
</template>;

export default class ThemePickerModal extends Component {
  @service toasts;

  @tracked themes = [];
  @tracked loading = true;
  @tracked saving = false;

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
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async selectTheme(theme) {
    if (this.saving) {
      return;
    }

    this.saving = true;

    try {
      await ajax(`/admin/themes/${theme.id}.json`, {
        type: "PUT",
        data: { theme: { default: true } },
      });

      setLocalTheme([], 0);

      this.toasts.success({
        data: {
          message: i18n("admin_onboarding_banner.select_theme.theme_set", {
            theme: theme.name,
          }),
        },
      });

      await this.args.model?.onThemeSelected?.();
      this.args.closeModal();
      window.location.reload();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DModal
      class="theme-picker-modal"
      @title={{i18n "admin_onboarding_banner.select_theme.modal_title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        {{#if this.loading}}
          <div class="theme-picker-modal__loading">
            {{dLoadingSpinner}}
          </div>
        {{else}}
          <div class="theme-picker-modal__themes">
            {{#each this.themes as |theme|}}
              <ThemeCard @theme={{theme}} @onSelect={{this.selectTheme}} />
            {{/each}}
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
