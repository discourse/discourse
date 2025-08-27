import Component from "@glimmer/component";
import { gt } from "truth-helpers";

const SCORE_TYPE_TO_CSS_CLASS_MAP = {
  illegal: "illegal",
  inappropriate: "inappropriate",
  needs_approval: "needs-approval",
  off_topic: "off-topic",
  spam: "spam",
};

/**
 * Displays a reason for a reviewable flag in the review process.
 * Renders the flag type, title, and the number of times this flag has been raised.
 *
 * @component ReviewableFlagReason
 *
 * @example
 * ```gjs
 * <ReviewableFlagReason @score={{this.score}} />
 * ```
 *
 * @param {Object} score - The score object containing flag information
 * @param {String} score.type - The type of flag (illegal, inappropriate, needs_approval, off_topic, spam)
 * @param {String} score.title - The display title for the flag reason
 * @param {Number} [score.count] - The number of times this flag has been raised
 */
export default class ReviewableFlagReason extends Component {
  /**
   * Determines the CSS class to apply based on the score type.
   * Maps known flag types to their corresponding CSS classes, defaults to "other" for unknown types.
   *
   * @returns {String} The CSS class modifier (e.g., "spam", "illegal", "other")
   */
  get scoreCSSClass() {
    return SCORE_TYPE_TO_CSS_CLASS_MAP[this.args.score.type] || "other";
  }

  <template>
    <span class="review-item__flag-reason --{{this.scoreCSSClass}}">
      {{#if (gt @score.count 0)}}
        <span class="review-item__flag-count --{{this.scoreCSSClass}}">
          {{@score.count}}
        </span>
      {{/if}}
      {{@score.title}}
    </span>
  </template>
}
