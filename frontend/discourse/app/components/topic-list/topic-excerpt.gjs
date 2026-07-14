import dDirSpan from "discourse/ui-kit/helpers/d-dir-span";
import { i18n } from "discourse-i18n";

const TopicExcerpt = <template>
  {{#if @topic.hasExcerpt}}
    <a href={{@topic.url}} class="topic-excerpt">
      {{dDirSpan @topic.escapedExcerpt htmlSafe="true"}}

      {{#if @topic.excerptTruncated}}
        <span class="topic-excerpt-more">{{i18n "read_more"}}</span>
      {{/if}}
    </a>
  {{/if}}
</template>;

export default TopicExcerpt;
