import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import BookmarkMenu from "discourse/components/bookmark-menu";
import PostBookmarkManager from "discourse/lib/post-bookmark-manager";

export default class PostMenuBookmarkButton extends Component {
  static shouldRender(args) {
    return !!args.post.canBookmark;
  }

  #bookmarkManager;

  get bookmarkManager() {
    // lazy instantiate the bookmark manager only if the component is rendered
    if (!this.#bookmarkManager) {
      this.#bookmarkManager = new PostBookmarkManager(
        getOwner(this),
        this.args.post
      );
    }

    return this.#bookmarkManager;
  }

  <template>
    {{#if @shouldRender}}
      <BookmarkMenu
        class="post-action-menu__bookmark"
        ...attributes
        @bookmarkManager={{this.bookmarkManager}}
        @showLabel={{@showLabel}}
      />
    {{/if}}
  </template>
}
