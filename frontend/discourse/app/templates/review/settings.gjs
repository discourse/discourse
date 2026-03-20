import { fn } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DNavItem from "discourse/ui-kit/d-nav-item";
import { i18n } from "discourse-i18n";

export default <template>
  <ul class="nav nav-pills reviewable-title">
    <DNavItem @route="review.index" @label="review.view_all" />
    <DNavItem @route="review.topics" @label="review.grouped_by_topic" />
    {{#if @controller.currentUser.admin}}
      <DNavItem
        @route="review.settings"
        @label="review.settings.title"
        @icon="wrench"
      />
    {{/if}}
  </ul>

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
