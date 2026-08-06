import Component from "@glimmer/component";
import { reactionsHiddenForUser } from "../lib/hidden-post";
import DiscourseReactionsActions from "./discourse-reactions-actions";

export default class ReactionsActionSummary extends Component {
  static extraControls = true;

  static shouldRender(args) {
    if (args.post.deleted) {
      return false;
    }

    if (args.post.reaction_users_count <= 0) {
      return false;
    }

    return !reactionsHiddenForUser(args.post);
  }

  <template>
    {{#if @shouldRender}}
      <div class="reactions-actions-summary">
        <DiscourseReactionsActions @post={{@post}} @position="left" />
      </div>
    {{/if}}
  </template>
}
