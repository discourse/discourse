import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

export default RouteTemplate(
  <template>
    <div class="reviewable-settings">
      <h4>{{i18n "review.settings.priorities.title"}}</h4>

      {{#each @controller.scoreTypes as |rst|}}
        <div class="reviewable-score-type">
          <div class="title">{{rst.title}}</div>
          <div class="field">
            <ComboBox
              @value={{rst.reviewable_priority}}
              @content={{@controller.settings.reviewable_priorities}}
              @onChange={{fn (mut rst.reviewable_priority)}}
            />
          </div>
        </div>
      {{/each}}

      <div class="reviewable-score-type">
        <div class="title"></div>
        <div class="field">
          <DButton
            @icon="check"
            @label="review.settings.save_changes"
            @action={{@controller.save}}
            @disabled={{@controller.saving}}
            class="btn-primary save-settings"
          />

          {{#if @controller.saved}}
            <span class="saved">{{i18n "review.settings.saved"}}</span>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
);
