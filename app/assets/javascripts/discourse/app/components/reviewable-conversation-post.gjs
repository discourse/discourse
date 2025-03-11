import Component from "@ember/component";
import { gte } from "@ember/object/computed";

export default class ReviewableConversationPost extends Component {
  @gte("index", 1) showUsername;
}
{{#if this.post}}
  <div class="reviewable-conversation-post">
    {{#if this.showUsername}}
      <LinkTo
        @route="user"
        @model={{this.post.user}}
        class="username"
      >@{{this.post.user.username}}</LinkTo>
    {{/if}}
    {{html-safe this.post.excerpt}}
  </div>
{{/if}}