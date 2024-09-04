import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { inject as service } from "@ember/service";
import BookmarkMenu from "discourse/components/bookmark-menu";
import PostBookmarkManager from "discourse/lib/post-bookmark-manager";

export default class PostMenuBookmarkButton extends Component {
  @service currentUser;

  bookmarkManager = new PostBookmarkManager(getOwner(this), this.args.post);

  <template>
    {{#if this.currentUser}}
      <BookmarkMenu ...attributes @bookmarkManager={{this.bookmarkManager}} />
    {{/if}}
  </template>
}
