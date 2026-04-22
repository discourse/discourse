import Component from "@glimmer/component";
import LikedUsersList from "../liked-users-list";

export default class PostMenuLikeCountButton extends Component {
  static extraControls = true;

  static shouldRender(args, _context, owner) {
    if (args.post.likeCount <= 0) {
      return false;
    }

    const siteSettings = owner?.lookup("service:site-settings");
    return !!siteSettings?.enable_new_post_reactions_menu;
  }

  <template><LikedUsersList ...attributes @post={{@post}} /></template>
}
