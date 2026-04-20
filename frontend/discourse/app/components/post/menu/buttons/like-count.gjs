import Component from "@glimmer/component";
import LikedUsersList from "../liked-users-list";

export default class PostMenuLikeCountButton extends Component {
  static extraControls = true;

  static shouldRender(args) {
    return args.post.likeCount > 0;
  }

  <template><LikedUsersList ...attributes @post={{@post}} /></template>
}
