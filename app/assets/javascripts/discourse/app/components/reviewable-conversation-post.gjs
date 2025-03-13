import Component from "@ember/component";
import { gte } from "@ember/object/computed";
import { LinkTo } from "@ember/routing";
import { htmlSafe } from "@ember/template";

export default class ReviewableConversationPost extends Component {
  @gte("index", 1) showUsername;

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
}
