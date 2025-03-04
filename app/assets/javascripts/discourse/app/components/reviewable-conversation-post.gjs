import Component from "@ember/component";
import { gte } from "@ember/object/computed";
import { LinkTo } from "@ember/routing";
import htmlSafe from "discourse/helpers/html-safe";

export default class ReviewableConversationPost extends Component {
  <template>
    {{#if this.post}}
      <div class="reviewable-conversation-post">
        {{#if this.showUsername}}
          <LinkTo
            @route="user"
            @model={{this.post.user}}
            class="username"
          >@{{this.post.user.username}}</LinkTo>
        {{/if}}
        {{htmlSafe this.post.excerpt}}
      </div>
    {{/if}}
  </template>
  @gte("index", 1) showUsername;
}
