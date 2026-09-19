import { fn } from "@ember/helper";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavItem from "discourse/ui-kit/d-nav-item";
import { i18n } from "discourse-i18n";

export default <template>
  <DHorizontalOverflowNav class="reviewable-title" @ariaLabel="Review">
    <DNavItem @label="review.view_all" @route="review.index" />
    <DNavItem @label="review.grouped_by_topic" @route="review.topics" />
    {{#if @controller.currentUser.admin}}
      <DNavItem
        @icon="wrench"
        @label="review.settings.title"
        @route="review.settings"
      />
    {{/if}}
  </DHorizontalOverflowNav>

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
