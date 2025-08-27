import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, not } from "truth-helpers";
import CookText from "discourse/components/cook-text";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class DiscourseNewFeatureItem extends Component {
  @service toasts;

  @tracked settingEnabled = this.args.item.setting_enabled;
  @tracked toggleSettingDisabled = false;
  @tracked isExperiment = this.args.item.experiment;

  @action
  async toggleExperiment() {
    if (this.toggleSettingDisabled) {
      this.toasts.error({
        duration: "short",
        data: {
          message: i18n("admin.dashboard.new_features.toggled_too_fast"),
        },
      });
      return;
    }
    this.settingEnabled = !this.settingEnabled;
    this.toggleSettingDisabled = true;

    setTimeout(() => {
      this.toggleSettingDisabled = false;
    }, 5000);
    try {
      await ajax("/admin/toggle-feature", {
        type: "POST",
        data: {
          setting_name: this.args.item.related_site_setting,
        },
      });

      const enabledMsg = this.isExperiment
        ? "admin.dashboard.new_features.experiment_enabled"
        : "admin.dashboard.new_features.feature_enabled";
      const disabledMsg = this.isExperiment
        ? "admin.dashboard.new_features.experiment_disabled"
        : "admin.dashboard.new_features.feature_disabled";

      this.toasts.success({
        duration: "short",
        data: {
          message: this.settingEnabled ? i18n(enabledMsg) : i18n(disabledMsg),
        },
      });
    } catch (error) {
      this.settingEnabled = !this.settingEnabled;
      return popupAjaxError(error);
    }
  }

  get tooltipTitle() {
    const experimentalTitleEnabled = this.isExperiment
      ? "admin.dashboard.new_features.experiment_tooltip.title_enabled"
      : "admin.dashboard.new_features.feature_tooltip.title_enabled";

    const experimentalTitleDisabled = this.isExperiment
      ? "admin.dashboard.new_features.feature_tooltip.title_disabled"
      : "admin.dashboard.new_features.feature_tooltip.title_disabled";

    return htmlSafe(
      i18n(
        this.settingEnabled
          ? experimentalTitleEnabled
          : experimentalTitleDisabled
      )
    );
  }

  get tooltipDescription() {
    const experimentalDescriptionEnabled = this.isExperiment
      ? "admin.dashboard.new_features.experiment_tooltip.content_enabled"
      : "admin.dashboard.new_features.feature_tooltip.content_enabled";

    const experimentalDescriptionDisabled = this.isExperiment
      ? "admin.dashboard.new_features.experiment_tooltip.content_disabled"
      : "admin.dashboard.new_features.feature_tooltip.content_disabled";

    return htmlSafe(
      i18n(
        this.settingEnabled
          ? experimentalDescriptionEnabled
          : experimentalDescriptionDisabled
      )
    );
  }

  <template>
    <div class="admin-new-feature-item">
      <div class="admin-new-feature-item__content">
        <div class="admin-new-feature-item__header">
          {{#if (and @item.emoji (not @item.screenshot_url))}}
            <div class="admin-new-feature-item__new-feature-emoji">
              {{@item.emoji}}
            </div>
          {{/if}}
          <h3>
            {{@item.title}}
            {{#if @item.experiment}}
              <span class="admin-new-feature-item__header-experimental">
                {{icon "flask"}}
                {{i18n "admin.dashboard.new_features.experimental"}}
              </span>
            {{/if}}
          </h3>
        </div>

        <div class="admin-new-feature-item__body-wrapper">
          {{#if @item.screenshot_url}}
            <div class="admin-new-feature-item__img-container">
              <img
                src={{@item.screenshot_url}}
                class="admin-new-feature-item__screenshot"
                alt={{@item.title}}
              />
            </div>
          {{/if}}

          <div class="admin-new-feature-item__body">
            <div class="admin-new-feature-item__feature-description">
              <CookText @rawText={{@item.description}} />

              {{#if @item.link}}
                <a
                  href={{@item.link}}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="admin-new-feature-item__learn-more"
                >
                  {{i18n "admin.dashboard.new_features.learn_more"}}
                </a>
              {{/if}}
            </div>
            {{#if @item.related_site_setting}}
              <div class="admin-new-feature-item__feature-toggle">
                <DTooltip>
                  <:trigger>
                    <DToggleSwitch
                      @state={{this.settingEnabled}}
                      {{on "click" this.toggleExperiment}}
                    />
                  </:trigger>
                  <:content>
                    <div class="admin-new-feature-item__tooltip">
                      <div class="admin-new-feature-item__tooltip-header">
                        {{this.tooltipTitle}}
                      </div>
                      <div class="admin-new-feature-item__tooltip-content">
                        {{this.tooltipDescription}}
                      </div>
                    </div>
                  </:content>
                </DTooltip>
              </div>
            {{/if}}
          </div>
        </div>
      </div>
    </div>
  </template>
}
