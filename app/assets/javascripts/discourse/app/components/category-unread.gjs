import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import iN from "discourse/helpers/i18n";

@tagName("span")
@classNames("category__badges")
export default class CategoryUnread extends Component {
  <template>
    {{#if this.unreadTopicsCount}}
      <a
        href={{this.category.unreadUrl}}
        title={{iN "topic.unread_topics" count=this.unreadTopicsCount}}
        class="badge new-posts badge-notification"
      >{{iN
          "filters.unread.lower_title_with_count"
          count=this.unreadTopicsCount
        }}</a>
    {{/if}}
    {{#if this.newTopicsCount}}
      <a
        href={{this.category.newUrl}}
        title={{iN "topic.new_topics" count=this.newTopicsCount}}
        class="badge new-posts badge-notification"
      >{{iN "filters.new.lower_title_with_count" count=this.newTopicsCount}}</a>
    {{/if}}
  </template>
}
