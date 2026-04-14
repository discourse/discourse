import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
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
    <DropdownMenu class="topic-bookmark-post-submenu" as |dropdown|>
      <dropdown.item
        class="bookmark-menu__row --jump"
        data-menu-option-id="jump"
      >
        <DButton
          @icon="arrow-right"
          @action={{this.jumpToPost}}
          class="bookmark-menu__row-btn"
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
          @icon="pencil"
          @label="edit"
          @action={{this.editBookmark}}
          class="bookmark-menu__row-btn"
        />
      </dropdown.item>
      <dropdown.item
        class="bookmark-menu__row --remove"
        data-menu-option-id="delete"
      >
        <DButton
          @icon="trash-can"
          @label="delete"
          @action={{this.deleteBookmark}}
          class="bookmark-menu__row-btn --danger"
        />
      </dropdown.item>
    </DropdownMenu>
  </template>
}
