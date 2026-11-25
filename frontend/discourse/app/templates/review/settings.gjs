import { fn } from "@ember/helper";
import ReviewableNav from "discourse/components/reviewable/nav";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  <ReviewableNav />

  <div class="reviewable-settings">
    <h4>{{i18n "review.settings.priorities.title"}}</h4>

    {{#each @controller.scoreTypes as |rst|}}
      <div class="reviewable-score-type">
        <div class="title">{{rst.title}}</div>
        <div class="field">
          <ComboBox
            @content={{@controller.settings.reviewable_priorities}}
            @onChange={{fn (mut rst.reviewable_priority)}}
            @value={{rst.reviewable_priority}}
          />
        </div>
      </div>
    {{/each}}

    <div class="reviewable-score-type">
      <div class="title"></div>
      <div class="field">
        <DButton
          class="btn-primary save-settings"
          @action={{@controller.save}}
          @disabled={{@controller.saving}}
          @icon="check"
          @label="review.settings.save_changes"
        />

        {{#if @controller.saved}}
          <span class="saved">{{i18n "review.settings.saved"}}</span>
        {{/if}}
      </div>
    </div>
  </div>
</template>
