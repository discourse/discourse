import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import BookmarkMenu from "discourse/components/bookmark-menu";
import PostBookmarkManager from "discourse/lib/post-bookmark-manager";

export default class PostMenuBookmarkButton extends Component {
  static shouldRender(post, context) {
    return !!context.currentUser;
  }

  bookmarkManager = new PostBookmarkManager(getOwner(this), this.args.post);

  <template>
    {{#if @shouldRender}}
      <BookmarkMenu ...attributes @bookmarkManager={{this.bookmarkManager}} />
    {{/if}}
  </template>
}
