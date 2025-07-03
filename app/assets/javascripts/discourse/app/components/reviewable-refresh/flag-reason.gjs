import Component from "@glimmer/component";
import { gt } from "truth-helpers";

const SCORE_TYPE_TO_CSS_CLASS_MAP = {
  illegal: "illegal",
  inappropriate: "inappropriate",
  needs_approval: "needs-approval",
  off_topic: "off-topic",
  spam: "spam",
};

export default class ReviewableFlagReason extends Component {
  get scoreCSSClass() {
    return `--${SCORE_TYPE_TO_CSS_CLASS_MAP[this.args.type] || "other"}`;
  }

  <template>
    <span class="review-item__flag-reason {{this.scoreCSSClass}}">
      {{#if (gt @count 0)}}
        <span class="review-item__flag-count {{this.scoreCSSClass}}">
          {{@count}}
        </span>
      {{/if}}

      {{@title}}
    </span>
  </template>
}
