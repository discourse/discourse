import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { gt } from "truth-helpers";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

const AiSentimentHorizontalBar = <template>
  {{#if (gt @score 0)}}
    <DTooltip
      class={{concat "sentiment-horizontal-bar__" @type}}
      style={{htmlSafe (concat "width: " @width "%")}}
    >
      <:trigger>
        <span class="sentiment-horizontal-bar__count">
          {{@score}}
        </span>
      </:trigger>
      <:content>
        {{i18n
          (concat
            "discourse_ai.sentiments.sentiment_analysis.filter_types." @type
          )
        }}:
        {{@score}}
      </:content>
    </DTooltip>
  {{/if}}
</template>;

export default AiSentimentHorizontalBar;
