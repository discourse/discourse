import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
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

class ThemeCard extends Component {
  @service interfaceColor;
  @service session;

  @tracked showingDarkScreenshot = this.#shouldShowDarkByDefault();
  @tracked previewExpanded = false;

  get currentScreenshotUrl() {
    const { screenshot_dark_url, screenshot_light_url } = this.args.theme;

    return this.showingDarkScreenshot
      ? screenshot_dark_url || screenshot_light_url
      : screenshot_light_url || screenshot_dark_url;
  }

  get screenshotToggleIcon() {
    return this.showingDarkScreenshot ? "sun" : "moon";
  }

  get screenshotToggleLabel() {
    return this.showingDarkScreenshot
      ? "admin_onboarding_banner.select_theme.show_light_screenshot"
      : "admin_onboarding_banner.select_theme.show_dark_screenshot";
  }

  get hasBothScreenshots() {
    return (
      this.args.theme.screenshot_light_url &&
      this.args.theme.screenshot_dark_url
    );
  }

  #shouldShowDarkByDefault() {
    return (
      this.interfaceColor?.colorModeIsDark ||
      window.matchMedia("(prefers-color-scheme: dark)").matches ||
      this.session?.defaultColorSchemeIsDark
    );
  }

  @action
  toggleScreenshot() {
    this.showingDarkScreenshot = !this.showingDarkScreenshot;
  }

  @action
  expandPreview() {
    this.previewExpanded = true;
  }

  @action
  collapsePreview() {
    this.previewExpanded = false;
  }

  <template>
    <div class="theme-picker-modal__card {{if @theme.default '--active'}}">
      <div class="theme-picker-modal__screenshot">
        {{#if this.currentScreenshotUrl}}
          <img src={{this.currentScreenshotUrl}} alt={{@theme.name}} />
          <div class="theme-picker-modal__screenshot-actions">
            {{#if this.hasBothScreenshots}}
              <DButton
                @action={{this.toggleScreenshot}}
                @ariaLabel={{this.screenshotToggleLabel}}
                @icon={{this.screenshotToggleIcon}}
                @preventFocus={{true}}
                @title={{this.screenshotToggleLabel}}
                class="btn-flat btn-small"
              />
            {{/if}}
            <DButton
              @action={{this.expandPreview}}
              @ariaLabel="admin_onboarding_banner.select_theme.expand_preview"
              @icon="expand"
              @preventFocus={{true}}
              @title="admin_onboarding_banner.select_theme.expand_preview"
              class="btn-flat btn-small"
            />
          </div>
        {{/if}}
      </div>
      <div class="theme-picker-modal__info">
        <span class="theme-picker-modal__name">{{@theme.name}}</span>
        {{#if @theme.default}}
          <span class="theme-picker-modal__badge">
            {{dIcon "check"}}
            {{i18n "admin_onboarding_banner.select_theme.current"}}
          </span>
        {{/if}}
      </div>
      {{#unless @theme.default}}
        <DButton
          @action={{fn @onSelect @theme}}
          @translatedLabel={{i18n
            "admin_onboarding_banner.select_theme.use_theme"
          }}
          class="btn-primary"
        />
      {{/unless}}
    </div>
    {{#if this.previewExpanded}}
      <div class="theme-picker-modal__lightbox">
        <button
          aria-label={{i18n
            "admin_onboarding_banner.select_theme.close_preview"
          }}
          class="theme-picker-modal__lightbox-backdrop"
          title={{i18n "admin_onboarding_banner.select_theme.close_preview"}}
          type="button"
          {{on "click" this.collapsePreview}}
        ></button>
        <img src={{this.currentScreenshotUrl}} alt={{@theme.name}} />
        <DButton
          @action={{this.collapsePreview}}
          @ariaLabel="admin_onboarding_banner.select_theme.close_preview"
          @icon="xmark"
          @title="admin_onboarding_banner.select_theme.close_preview"
          class="btn-flat theme-picker-modal__lightbox-close"
        />
      </div>
    {{/if}}
  </template>
}

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
