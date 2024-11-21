import dirSpan from "discourse/helpers/dir-span";
import { i18n } from "discourse-i18n";

const TopicExcerpt = <template>
  {{#if @topic.hasExcerpt}}
    <a href={{@topic.url}} class="topic-excerpt">
      {{dirSpan @topic.escapedExcerpt htmlSafe="true"}}

      {{#if @topic.excerptTruncated}}
        <span class="topic-excerpt-more">{{i18n "read_more"}}</span>
      {{/if}}
    </a>
  {{/if}}
</template>;

export default TopicExcerpt;
