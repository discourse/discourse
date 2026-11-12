import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

export default class TopicBookmarkPostSubmenu extends Component {
  get bookmark() {
    return this.args.data.bookmark;
  }

  @action
  jumpToPost() {
    this.args.close();
    this.args.data.onJumpToPost(this.bookmark);
  }

  @action
  editBookmark() {
    this.args.close();
    this.args.data.onEditPostBookmark(this.bookmark);
  }

  @action
  deleteBookmark() {
    this.args.close();
    this.args.data.onRemoveBookmark(this.bookmark);
  }

  <template>
    <DDropdownMenu class="topic-bookmark-post-submenu" as |dropdown|>
      <dropdown.item
        class="bookmark-menu__row --jump"
        data-menu-option-id="jump"
      >
        <DButton
          class="bookmark-menu__row-btn"
          @action={{this.jumpToPost}}
          @icon="arrow-right"
        >
          <span class="bookmark-menu__row-label">
            {{i18n
              "bookmarks.jump_to_post"
              post_number=this.bookmark.post_number
            }}
          </span>
        </DButton>
      </dropdown.item>
      <dropdown.item
        class="bookmark-menu__row --edit"
        data-menu-option-id="edit"
      >
        <DButton
          class="bookmark-menu__row-btn"
          @action={{this.editBookmark}}
          @icon="pencil"
          @label="edit"
        />
      </dropdown.item>
      <dropdown.item
        class="bookmark-menu__row --remove"
        data-menu-option-id="delete"
      >
        <DButton
          class="bookmark-menu__row-btn --danger"
          @action={{this.deleteBookmark}}
          @icon="trash-can"
          @label="delete"
        />
      </dropdown.item>
    </DDropdownMenu>
  </template>
}
