import Component from "@glimmer/component";
import { actionDescriptionHtml } from "discourse/widgets/post-small-action";

export default class PostActionDescription extends Component {
  get description() {
    if (this.args.actionCode && this.args.createdAt) {
      return actionDescriptionHtml(
        this.args.actionCode,
        this.args.createdAt,
        this.args.username,
        this.args.path
      );
    }
  }

  <template>
    {{#if this.description}}
      <p class="excerpt">{{this.description}}</p>
    {{/if}}
  </template>
}
