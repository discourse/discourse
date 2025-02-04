import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import BookmarkMenu from "discourse/components/bookmark-menu";
import PostBookmarkManager from "discourse/lib/post-bookmark-manager";

export default class PostMenuBookmarkButton extends Component {
  static shouldRender(args) {
    return !!args.post.canBookmark;
  }

  @cached
  get bookmarkManager() {
    return new PostBookmarkManager(getOwner(this), this.args.post);
  }

  <template>
    <BookmarkMenu
      class="post-action-menu__bookmark"
      ...attributes
      @bookmarkManager={{this.bookmarkManager}}
      @showLabel={{@showLabel}}
    />
  </template>
}
