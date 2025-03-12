{{#if this.unreadTopicsCount}}
  <a
    href={{this.category.unreadUrl}}
    title={{i18n "topic.unread_topics" count=this.unreadTopicsCount}}
    class="badge new-posts badge-notification"
  >{{i18n
      "filters.unread.lower_title_with_count"
      count=this.unreadTopicsCount
    }}</a>
{{/if}}
{{#if this.newTopicsCount}}
  <a
    href={{this.category.newUrl}}
    title={{i18n "topic.new_topics" count=this.newTopicsCount}}
    class="badge new-posts badge-notification"
  >{{i18n "filters.new.lower_title_with_count" count=this.newTopicsCount}}</a>
{{/if}}