import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class TopicPostBadges extends Component {
  @service currentUser;

  get displayUnreadPosts() {
    return this.args.newPosts || this.args.unreadPosts;
  }

  get newDotText() {
    return this.currentUser?.trust_level > 0
      ? " "
      : i18n("filters.new.lower_title");
  }

  <template>
    {{~! no whitespace ~}}
    <span class="topic-post-badges">
      {{~#if this.displayUnreadPosts~}}
        {{! eslint-disable-next-line ember/template-no-unsupported-role-attributes }}
        &nbsp;<a
          aria-description={{i18n
            "topic.unread_posts"
            count=this.displayUnreadPosts
          }}
          class="badge badge-notification unread-posts"
          href={{@url}}
          title={{i18n "topic.unread_posts" count=this.displayUnreadPosts}}
        >{{this.displayUnreadPosts}}</a>
      {{~/if~}}

      {{~#if @unseen~}}
        &nbsp;<a
          aria-label={{i18n "topic.new"}}
          class="badge badge-notification new-topic"
          href={{@url}}
          title={{i18n "topic.new"}}
        >{{this.newDotText}}</a>
      {{~/if~}}
    </span>
    {{~! no whitespace ~}}
  </template>
}
