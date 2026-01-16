import { gt } from "discourse/truth-helpers";

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
const ReviewableFlagReason = <template>
  <span class="review-item__flag-reason">
    {{@score.title}}
    {{#if (gt @score.count 1)}}
      <span class="review-item__flag-count">
        x{{@score.count}}
      </span>
    {{/if}}
  </span>
</template>;

export default ReviewableFlagReason;
