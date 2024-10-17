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
import DTooltip from "float-kit/components/d-tooltip";

export default class DiscourseNewFeatureItem extends Component {
  @service siteSettings;
  @tracked enabled;

  @bind
  initEnabled() {
    this.enabled = this.siteSettings[this.args.item.experiment_setting];
  }

  @action
  async toggle() {
    this.enabled = !this.enabled;
    try {
      await ajax("/admin/toggle-feature", {
        type: "POST",
        data: {
          setting_name: this.args.item.experiment_setting,
        },
      });
    } catch (error) {
      this.enabled = !this.enabled;
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

        <div class="admin-new-feature-item__body">
          {{#if @item.screenshot_url}}
            <img
              src={{@item.screenshot_url}}
              class="admin-new-feature-item__screenshot"
              alt={{@item.title}}
            />
          {{/if}}

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
                    @state={{this.enabled}}
                    {{on "click" this.toggle}}
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
