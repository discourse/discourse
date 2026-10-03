import { or } from "discourse/truth-helpers";
import dElement from "discourse/ui-kit/helpers/d-element";
import { i18n } from "discourse-i18n";

const CategoryUnread = <template>
  {{#let (dElement (or @tagName "span")) as |TagName|}}
    <TagName class="category__badges" ...attributes>
      {{#if @unreadTopicsCount}}
        <a
          class="badge new-posts badge-notification"
          href={{@category.unreadUrl}}
          title={{i18n "topic.unread_topics" count=@unreadTopicsCount}}
        >{{i18n
            "filters.unread.lower_title_with_count"
            count=@unreadTopicsCount
          }}</a>
      {{/if}}
      {{#if @newTopicsCount}}
        <a
          class="badge new-posts badge-notification"
          href={{@category.newUrl}}
          title={{i18n "topic.new_topics" count=@newTopicsCount}}
        >{{i18n "filters.new.lower_title_with_count" count=@newTopicsCount}}</a>
      {{/if}}
    </TagName>
  {{/let}}
</template>;

export default CategoryUnread;
