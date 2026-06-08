import Component from "@glimmer/component";
import { applyValueTransformer } from "discourse/lib/transformer";
import { reactionsHiddenForUser } from "../lib/hidden-post";
import DiscourseReactionsActions from "./discourse-reactions-actions";

export default class ReactionsActionButton extends Component {
  static shouldRender(args) {
    if (reactionsHiddenForUser(args.post)) {
      return false;
    }

    const show = args.post.showLike || args.post.likeCount > 0;
    return applyValueTransformer("like-button-render-decision", show, {
      post: args.post,
    });
  }

  <template>
    <div class="discourse-reactions-actions-button-shim">
      <DiscourseReactionsActions
        @post={{@post}}
        @showLogin={{@buttonActions.showLogin}}
      />
    </div>
  </template>
}
