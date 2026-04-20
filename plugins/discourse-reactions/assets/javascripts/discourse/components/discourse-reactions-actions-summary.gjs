import Component from "@glimmer/component";
import DiscourseReactionsActions from "./discourse-reactions-actions";

export default class ReactionsActionSummary extends Component {
  static extraControls = true;

  static shouldRender(args) {
    if (args.post.deleted) {
      return false;
    }

    return args.post.reaction_users_count > 0;
  }

  <template>
    {{#if @shouldRender}}
      <div>
        <DiscourseReactionsActions @post={{@post}} @position="left" />
      </div>
    {{/if}}
  </template>
}
