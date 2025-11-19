import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DecoratedHtml from "discourse/components/decorated-html";
import PluginOutlet from "discourse/components/plugin-outlet";
import ReviewablePostEdits from "discourse/components/reviewable-post-edits";
import ReviewableCreatedBy from "discourse/components/reviewable-refresh/created-by";
import ReviewableTopicLink from "discourse/components/reviewable-refresh/topic-link";
import lazyHash from "discourse/helpers/lazy-hash";
import { bind } from "discourse/lib/decorators";
import highlightHTML from "discourse/lib/highlight-html";
import { i18n } from "discourse-i18n";

export default class ReviewablePost extends Component {
  @service appEvents;

  get metaLabel() {
    return this.args.metaLabel || i18n("review.posted_in");
  }

  get userLabel() {
    return this.args.userLabel || i18n("review.review_user");
  }

  get pluginOutletName() {
    return this.args.pluginOutletName || "after-reviewable-post-body";
  }

  @bind
  decorate(element, helper) {
    const reviewable = this.args.reviewable;
    if (reviewable?.reviewable_scores) {
      const words = reviewable.reviewable_scores
        .map((rs) => {
          return rs.reason_type === "watched_word" ? rs.reason_data : [];
        })
        .flat();

      if (words.length > 0) {
        words.forEach((word) => {
          highlightHTML(element, word, {
            nodeName: "mark",
            className: "watched-word-highlight",
          });
        });
      }
    }

    this.appEvents.trigger(
      "decorate-non-stream-cooked-element",
      element,
      helper
    );
  }

  <template>
    <div class="review-item__meta-content">
      <div class="review-item__meta-label">{{this.metaLabel}}</div>

      <div class="review-item__meta-topic-title">
        <ReviewableTopicLink @reviewable={{@reviewable}} @tagName="" />
        <ReviewablePostEdits @reviewable={{@reviewable}} @tagName="" />
      </div>

      <div class="review-item__meta-label">{{this.userLabel}}</div>

      <div class="review-item__meta-flagged-user">
        <ReviewableCreatedBy @user={{@reviewable.target_created_by}} />
      </div>
    </div>

    <div class="review-item__post">
      <div class="review-item__post-content-wrapper">
        {{#if @reviewable.blank_post}}
          <div class="review-item__post-content">
            <p>{{i18n "review.deleted_post"}}</p>
          </div>
        {{else}}
          <DecoratedHtml
            @className="review-item__post-content"
            @html={{htmlSafe @reviewable.cooked}}
            @decorate={{this.decorate}}
            @model={{@reviewable}}
          />
        {{/if}}

        <span>
          <PluginOutlet
            @name={{this.pluginOutletName}}
            @connectorTagName="div"
            @outletArgs={{lazyHash model=@reviewable}}
          />
        </span>

        {{yield}}
      </div>
    </div>
  </template>
}
