import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import NavItem from "discourse/components/nav-item";
import ReviewIndexLegacy from "discourse/components/review-index-legacy";
import ReviewIndexRefresh from "discourse/components/review-index-refresh";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ReviewIndex extends Component {
  @service currentUser;

  get shouldUseRefreshUI() {
    return this.currentUser?.use_reviewable_ui_refresh;
  }

  <template>
    <ul class="nav nav-pills reviewable-title">
      <NavItem @route="review.index" @label="review.view_all" />
      <NavItem @route="review.topics" @label="review.grouped_by_topic" />
      {{#if @controller.currentUser.admin}}
        <NavItem
          @route="review.settings"
          @label="review.settings.title"
          @icon="wrench"
        />
      {{/if}}
    </ul>
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
        <span class="text">{{htmlSafe
            (i18n
              "review.unknown.instruction"
              url="https://meta.discourse.org/t/350179"
            )
          }}</span>
        <div class="unknown-reviewables__options">
          <LinkTo @route="adminPlugins.index" class="btn">
            {{icon "puzzle-piece"}}
            <span>{{i18n "review.unknown.enable_plugins"}}</span>
          </LinkTo>
          <DButton
            @label="review.unknown.ignore_all"
            @icon="trash-can"
            @action={{@controller.ignoreAllUnknownTypes}}
            class="btn-default"
          />
        </div>
      </div>
    {{/if}}

    {{#if this.shouldUseRefreshUI}}
      <ReviewIndexRefresh @controller={{@controller}} />
    {{else}}
      <ReviewIndexLegacy @controller={{@controller}} />
    {{/if}}
  </template>
}
