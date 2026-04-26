import Component from "@glimmer/component";
import DiscourseReactionsActions from "./discourse-reactions-actions";

export default class ReactionsActionSummary extends Component {
  static extraControls = true;

  static shouldRender(args, _context, owner) {
    if (args.post.deleted) {
      return false;
    }

    if (args.post.reaction_users_count <= 0) {
      return false;
    }

    const siteSettings = owner?.lookup("service:site-settings");
    if (siteSettings?.enable_new_post_reactions_menu) {
      return true;
    }

    const site = owner?.lookup("service:site");
    if (site?.mobileView) {
      return false;
    }

    const mainReaction = siteSettings?.discourse_reactions_reaction_for_like;
    return !(
      args.post.reactions &&
      args.post.reactions.length === 1 &&
      args.post.reactions[0].id === mainReaction
    );
  }

  <template>
    {{#if @shouldRender}}
      <div>
        <DiscourseReactionsActions @post={{@post}} @position="left" />
      </div>
    {{/if}}
  </template>
}
