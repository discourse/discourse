import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { and, not } from "truth-helpers";
import CookText from "discourse/components/cook-text";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import dIcon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class DiscourseNewFeatureItem extends Component {
  @service siteSettings;
  @service toasts;
  @tracked experimentEnabled = this.args.item.experiment_enabled;
  @tracked toggleExperimentDisabled = false;

  @action
  async toggleExperiment() {
    if (this.toggleExperimentDisabled) {
      this.toasts.error({
        duration: 3000,
        data: {
          message: i18n(
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
            ? i18n("admin.dashboard.new_features.experiment_enabled")
            : i18n("admin.dashboard.new_features.experiment_disabled"),
        },
      });
    } catch (error) {
      this.experimentEnabled = !this.experimentEnabled;
      return popupAjaxError(error);
    }
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
            {{#if @item.experiment_setting}}
              <span class="admin-new-feature-item__header-experimental">
                {{dIcon "flask"}}
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
                          (if
                            this.experimentEnabled
                            "admin.dashboard.new_features.experiment_tooltip.title_enabled"
                            "admin.dashboard.new_features.experiment_tooltip.title_disabled"
                          )
                        }}
                      </div>
                      <div class="admin-new-feature-item__tooltip-content">
                        {{htmlSafe
                          (i18n
                            (if
                              this.experimentEnabled
                              "admin.dashboard.new_features.experiment_tooltip.content_enabled"
                              "admin.dashboard.new_features.experiment_tooltip.content_disabled"
                            )
                          )
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
    </div>
  </template>
}
