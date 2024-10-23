import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { and, not } from "truth-helpers";
import CookText from "discourse/components/cook-text";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class DiscourseNewFeatureItem extends Component {
  @service siteSettings;
  @service toasts;
  @tracked experimentEnabled;
  @tracked toggleExperimentDisabled = false;

  @bind
  initEnabled() {
    this.experimentEnabled =
      this.siteSettings[this.args.item.experiment_setting];
  }

  @action
  async toggleExperiment() {
    if (this.toggleExperimentDisabled) {
      this.toasts.error({
        duration: 3000,
        data: {
          message: I18n.t(
            "admin.dashboard.new_features.experiment_toggled_too_fast"
          ),
        },
      });
      return;
    }
    this.experimentEnabled = !this.experimentEnabled;
    this.toggleExperimentDisabled = true;

    setTimeout(() => {
      this.toggleExperimentDisabled = false;
    }, 5000);
    try {
      await ajax("/admin/toggle-feature", {
        type: "POST",
        data: {
          setting_name: this.args.item.experiment_setting,
        },
      });
      this.toasts.success({
        duration: 3000,
        data: {
          message: this.experimentEnabled
            ? I18n.t("admin.dashboard.new_features.experiment_enabled")
            : I18n.t("admin.dashboard.new_features.experiment_disabled"),
        },
      });
    } catch (error) {
      this.experimentEnabled = !this.experimentEnabled;
      return popupAjaxError(error);
    }
  }

  <template>
    <div class="admin-new-feature-item" {{didInsert this.initEnabled}}>
      <div class="admin-new-feature-item__content">
        <div class="admin-new-feature-item__header">
          {{#if (and @item.emoji (not @item.screenshot_url))}}
            <div class="admin-new-feature-item__new-feature-emoji">
              {{@item.emoji}}
            </div>
          {{/if}}
          <h3>
            {{@item.title}}
          </h3>
          {{#if @item.discourse_version}}
            <div class="admin-new-feature-item__new-feature-version">
              {{@item.discourse_version}}
            </div>
          {{/if}}
        </div>

        {{#if @item.screenshot_url}}
          <img
            src={{@item.screenshot_url}}
            class="admin-new-feature-item__screenshot"
            alt={{@item.title}}
          />
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
          {{#if @item.experiment_setting}}
            <div class="admin-new-feature-item__feature-toggle">
              <DTooltip>
                <:trigger>
                  <DToggleSwitch
                    @state={{this.experimentEnabled}}
                    {{on "click" this.toggleExperiment}}
                  />
                </:trigger>
                <:content>
                  <div class="admin-new-feature-item__tooltip">
                    <div class="admin-new-feature-item__tooltip-header">
                      {{i18n
                        "admin.dashboard.new_features.experiment_tooltip.title"
                      }}
                    </div>
                    <div class="admin-new-feature-item__tooltip-content">
                      {{i18n
                        "admin.dashboard.new_features.experiment_tooltip.content"
                      }}
                    </div>
                  </div>
                </:content>
              </DTooltip>
            </div>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
