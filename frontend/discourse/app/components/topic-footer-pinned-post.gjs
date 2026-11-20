import DDecoratedHtml from "discourse/ui-kit/d-decorated-html";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import DUserLink from "discourse/ui-kit/d-user-link";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if (and @topic.pinned_footer_post (not @topic.isPrivateMessage))}}
    {{#let @topic.pinned_footer_post as |post|}}
      <aside class="topic-footer-pinned-post">
        <h2>{{i18n "topic.pinned_footer_post.title"}}</h2>
        {{#if post.username}}
          <DUserAvatar @size="small" @user={{post}} />
          <DUserLink @user={{post}}>{{post.username}}</DUserLink>
        {{/if}}
        <DDecoratedHtml class="cooked" @html={{post.cooked}} />
        <a href={{post.relative_url}}>{{i18n
            "topic.pinned_footer_post.view_original"
          }}</a>
      </aside>
    {{/let}}
  {{/if}}
</template>
