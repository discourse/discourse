import { eq } from "discourse/truth-helpers";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import { i18n } from "discourse-i18n";

/**
 * A topic laid out like a row of a topic list: its title and last activity,
 * then its category and reply count.
 */
const AiSearchTopicRow = <template>
  <a class="ai-search-topic-row" href={{@url}} ...attributes>
    <span class="ai-search-topic-row__title">{{dReplaceEmoji @title}}</span>
    {{#if @bumpedAt}}
      <span class="ai-search-topic-row__date">
        {{dFormatDate @bumpedAt format="tiny"}}
      </span>
    {{/if}}
    {{#if @category}}
      <span class="ai-search-topic-row__category">
        {{dCategoryLink @category link=false}}
      </span>
    {{/if}}
    {{#unless (eq @replyCount undefined)}}
      <span
        class="ai-search-topic-row__replies"
        title={{i18n
          "discourse_ai.ai_search.related_replies"
          count=@replyCount
        }}
      >
        {{dIcon "reply"}}
        {{dNumber @replyCount}}
      </span>
    {{/unless}}
  </a>
</template>;

export default AiSearchTopicRow;
