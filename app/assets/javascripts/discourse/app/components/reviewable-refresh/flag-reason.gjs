import Component from "@glimmer/component";
import { gt } from "truth-helpers";

export default class ReviewableFlagReason extends Component {
  get scoreCSSClass() {
    return `--${this.args.type || "others"} `;
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
