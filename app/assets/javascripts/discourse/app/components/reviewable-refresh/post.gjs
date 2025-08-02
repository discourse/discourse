import Component from "@glimmer/component";
import PluginOutlet from "discourse/components/plugin-outlet";
import ReviewablePostEdits from "discourse/components/reviewable-post-edits";
import ReviewableCreatedBy from "discourse/components/reviewable-refresh/created-by";
import ReviewableTopicLink from "discourse/components/reviewable-refresh/topic-link";
import lazyHash from "discourse/helpers/lazy-hash";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import { i18n } from "discourse-i18n";

export default class ReviewablePost extends Component {
  get metaLabel() {
    return this.args.metaLabel || i18n("review.posted_in");
  }

  get userLabel() {
    return this.args.userLabel || i18n("review.review_user");
  }

  get pluginOutletName() {
    return this.args.pluginOutletName || "after-reviewable-post-body";
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
        <div class="review-item__post-content">
          {{#if @reviewable.blank_post}}
            <p>{{i18n "review.deleted_post"}}</p>
          {{else}}
            {{highlightWatchedWords @reviewable.cooked @reviewable}}
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
    </div>
  </template>
}
