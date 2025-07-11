import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import BookmarkMenu from "discourse/components/bookmark-menu";
import PostBookmarkManager from "discourse/lib/post-bookmark-manager";

export default class PostMenuBookmarkButton extends Component {
  static shouldRender(args) {
    return !!args.post.canBookmark;
  }

  @service appEvents;

  constructor() {
    super(...arguments);
    this.bookmarkManager = new PostBookmarkManager(
      getOwner(this),
      this.args.post
    );
    this.appEvents.on("bookmarks:changed", this, this.handleBookmarksChanged);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.appEvents.off("bookmarks:changed", this, this.handleBookmarksChanged);
  }

  handleBookmarksChanged(data, other) {
    // if (other.targetId !== this.args.post.id || other.target !== "post") {
    //   return;
    // }
    // // The bookmark has been deleted by "Clear Bookmarks"
    // if (!data) {
    //   this.bookmarkManager.reset();
    //   return;
    // }
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
