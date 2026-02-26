import Component from "@glimmer/component";
import { dasherize } from "@ember/string";
import CookText from "discourse/components/cook-text";
import { and, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class DiscourseNewFeatureItem extends Component {
  get identifier() {
    return this.args.item.title ? dasherize(this.args.item.title) : null;
  }

  <template>
    <div
      class="admin-new-feature-item"
      data-new-feature-identifier={{this.identifier}}
    >
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
          </div>
        </div>
      </div>
    </div>
  </template>
}
