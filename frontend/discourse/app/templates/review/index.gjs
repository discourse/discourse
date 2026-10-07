import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import ReviewIndex from "discourse/components/reviewable/index";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavItem from "discourse/ui-kit/d-nav-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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
  {{#if @controller.displayUnknownReviewableTypesWarning}}
    <div class="alert alert-info unknown-reviewables">
      <span class="text">{{i18n
          "review.unknown.title"
          count=@controller.unknownReviewableTypes.length
        }}</span>

      <ul>
        {{#each @controller.unknownReviewableTypes as |reviewable|}}
          {{#if (eq reviewable.source @controller.unknownTypeSource)}}
            <li>{{i18n
                "review.unknown.reviewable_unknown_source"
                reviewableType=reviewable.type
              }}</li>
          {{else}}
            <li>{{i18n
                "review.unknown.reviewable_known_source"
                reviewableType=reviewable.type
                pluginName=reviewable.source
              }}</li>
          {{/if}}
        {{/each}}
      </ul>
      <span class="text">{{trustHTML
          (i18n
            "review.unknown.instruction"
            url="https://meta.discourse.org/t/350179"
          )
        }}</span>
      <div class="unknown-reviewables__options">
        <LinkTo class="btn" @route="adminPlugins.index">
          {{dIcon "puzzle-piece"}}
          <span>{{i18n "review.unknown.enable_plugins"}}</span>
        </LinkTo>
        <DButton
          class="btn-default"
          @action={{@controller.ignoreAllUnknownTypes}}
          @icon="trash-can"
          @label="review.unknown.ignore_all"
        />
      </div>
    </div>
  {{/if}}

  <ReviewIndex @controller={{@controller}} />
</template>
