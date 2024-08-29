import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { isEmpty, isPresent } from "@ember/utils";
import { and, eq } from "truth-helpers";
import SmallUserList from "discourse/components/small-user-list";
import UserTip from "discourse/components/user-tip";
import concatClass from "discourse/helpers/concat-class";
import { userPath } from "discourse/lib/url";
import i18n from "discourse-common/helpers/i18n";
import discourseLater from "discourse-common/lib/later";
import { bind } from "discourse-common/utils/decorators";
import LikeButton from "./buttons/like";
import ShowMoreButton from "./buttons/show-more";

const LIKE_ACTION = 2;
const VIBRATE_DURATION = 5;

const BOOKMARK_BUTTON_ID = "bookmark";
const EDIT_BUTTON_ID = "edit";
const FLAG_BUTTON_ID = "flag";
const LIKE_BUTTON_ID = "like";
const READ_BUTTON_ID = "read";
const REPLY_BUTTON_ID = "reply";
const REPLY_SMALL_BUTTON_ID = "reply-small";
const SHOW_MORE_BUTTON_ID = "show-more";
const WIKI_EDIT_BUTTON_ID = "wiki-edit";

let registeredPostMenuButtons;
resetPostMenuButtons();

function resetPostMenuButtons() {
  registeredPostMenuButtons = new Map();

  registeredPostMenuButtons.set(BOOKMARK_BUTTON_ID, <template>
    <span>BOOKMARK</span>
  </template>);
  registeredPostMenuButtons.set(EDIT_BUTTON_ID, <template>
    <span>EDIT</span>
  </template>);
  registeredPostMenuButtons.set(FLAG_BUTTON_ID, <template>
    <span>FLAG</span>
  </template>);
  registeredPostMenuButtons.set(LIKE_BUTTON_ID, LikeButton);
  registeredPostMenuButtons.set(READ_BUTTON_ID, <template>
    <span>READ</span>
  </template>);
  registeredPostMenuButtons.set(REPLY_BUTTON_ID, <template>
    <span>REPLY</span>
  </template>);
  registeredPostMenuButtons.set(REPLY_SMALL_BUTTON_ID, <template>
    <span>REPLY_SMALL</span>
  </template>);
  registeredPostMenuButtons.set(WIKI_EDIT_BUTTON_ID, <template>
    <span>WIKI_EDIT</span>
  </template>);
  registeredPostMenuButtons.set(SHOW_MORE_BUTTON_ID, ShowMoreButton);
}

export function clearExtraPostMenuButtons() {
  resetPostMenuButtons();
}

function smallUserAttributes(user) {
  return {
    template: user.avatar_template,
    username: user.username,
    post_url: user.post_url,
    url: userPath(user.username_lower),
    unknown: user.unknown,
  };
}

export default class PostMenu extends Component {
  @service capabilities;
  @service currentUser;
  @service keyValueStore;
  @service siteSettings;
  @service store;

  @tracked collapsed = true; // TODO some plugins will need a value transformer
  @tracked likedUsers = [];
  @tracked totalLikedUsers;
  @tracked readers = [];
  @tracked totalReaders;

  get items() {
    return this.#configuredItems.map((i) => {
      // if the post is a wiki, make Edit more prominent
      if (this.args.transformedPost.wiki && this.args.transformedPost.canEdit) {
        switch (i) {
          case EDIT_BUTTON_ID:
            return REPLY_SMALL_BUTTON_ID;
          case REPLY_BUTTON_ID:
            return WIKI_EDIT_BUTTON_ID;
        }
      }

      return i;
    });
  }

  get buttons() {
    const items = this.items
      .map((itemId) => {
        const button = registeredPostMenuButtons.get(itemId);

        if (button) {
          // assign the name as a property to the button so we can compare it against other configurations
          // like the list of hidden items for example
          button.postMenuButtonId = itemId;
        }

        return button;
      })
      .filter(isPresent);

    return items;
  }

  get collapsedButtons() {
    const hiddenItems = this.#hiddenItems;

    if (isEmpty(hiddenItems) || !this.collapsed) {
      return [];
    }

    return this.buttons.filter((button) => {
      if (this.args.transformedPost.yours && button.alwaysShowYours) {
        return false;
      }

      if (
        this.args.transformedPost.reviewableId &&
        button.postMenuButtonId === FLAG_BUTTON_ID
      ) {
        return false;
      }

      return hiddenItems.includes(button.postMenuButtonId);
    });
  }

  get hasShowMoreButton() {
    // Only show ellipsis if there is more than one button hidden
    // if there are no more buttons, we are not collapsed
    return this.collapsedButtons.length > 1;
  }

  get visibleButtons() {
    if (!this.hasShowMoreButton) {
      return this.buttons;
    }

    const buttons = this.buttons.filter((button) => {
      return !this.collapsedButtons.includes(button);
    });

    const showMoreButton = registeredPostMenuButtons.get(SHOW_MORE_BUTTON_ID);
    showMoreButton.postMenuButtonId = SHOW_MORE_BUTTON_ID;
    buttons.push(showMoreButton);

    return buttons;
  }

  get remainingLikedUsers() {
    return this.totalLikedUsers - this.likedUsers.length;
  }

  get remainingReaders() {
    return this.totalReaders - this.readers.length;
  }

  @bind
  actionFor(button) {
    switch (button.postMenuButtonId) {
      case LIKE_BUTTON_ID:
        return this.like;
      case SHOW_MORE_BUTTON_ID:
        return this.showMoreActions;
    }
  }

  @action
  async like({ onBeforeToggle } = {}) {
    if (!this.currentUser) {
      this.keyValueStore &&
        this.keyValueStore.set({
          key: "likedPostId",
          value: this.args.transformedPost.id,
        });
      return this.sendWidgetAction("showLogin");
    }

    if (this.capabilities.userHasBeenActive && this.capabilities.canVibrate) {
      navigator.vibrate(VIBRATE_DURATION);
    }

    if (this.args.transformedPost.liked) {
      return this.args.toggleLike();
    }

    onBeforeToggle?.(this.args.transformedPost.liked);

    return new Promise((resolve) => {
      discourseLater(async () => {
        await this.args.toggleLike();
        resolve();
      }, 400);
    });
  }

  @action
  async showMoreActions() {
    this.collapsed = false;

    const fetchData = [
      !this.likedUsers.length && this.#fetchWhoLiked(),
      !this.readers.length &&
        this.args.transformedPost.showReadIndicator &&
        this.#fetchWhoRead(),
    ].filter(Boolean);

    await Promise.all(fetchData);
  }

  get #configuredItems() {
    return this.siteSettings.post_menu.split("|").filter(Boolean);
  }

  get #hiddenItems() {
    const setting = this.siteSettings.post_menu_hidden_items;

    if (isEmpty(setting)) {
      return [];
    }

    return setting
      .split("|")
      .filter(
        (itemId) =>
          !this.args.transformedPost.bookmarked || itemId !== BOOKMARK_BUTTON_ID
      );
  }

  async #fetchWhoLiked() {
    const users = await this.store.find("post-action-user", {
      id: this.args.transformedPost.id,
      post_action_type_id: LIKE_ACTION,
    });

    this.likedUsers = users.map(smallUserAttributes);
    this.totalLikedUsers = users.totalRows;
  }

  async #fetchWhoRead() {
    const users = await this.store.find("post-reader", {
      id: this.args.transformedPost.id,
    });

    this.readers = users.map(smallUserAttributes);
    this.totalReaders = users.totalRows;
  }

  <template>
    <section class="post-menu-area clearfix">
      <nav
        class={{concatClass
          "post-controls"
          (if this.hasShowMoreButton "collapsed" "expanded")
          (if
            this.siteSettings.enable_filtered_replies_view
            "replies-button-visible"
          )
        }}
      >
        <div class="actions">
          {{#each this.visibleButtons as |Button|}}
            <Button
              @transformedPost={{@transformedPost}}
              @action={{this.actionFor Button}}
            />
          {{/each}}
        </div>
      </nav>
      {{#if this.readers}}
        <SmallUserList
          class="who-read"
          aria-label={{i18n
            "post.actions.people.sr_post_readers_list_description"
          }}
          @users={{this.readers}}
          @addSelf={{false}}
          @count={{if
            this.remainingReaders
            this.remainingReaders
            this.totalReaders
          }}
          @description={{if
            this.remainingReaders
            "post.actions.people.read_capped"
            "post.actions.people.read"
          }}
        />
      {{/if}}
      {{#if this.likedUsers}}
        <SmallUserList
          class="who-liked"
          aria-label={{i18n
            "post.actions.people.sr_post_likers_list_description"
          }}
          @users={{this.likedUsers}}
          @addSelf={{and
            @transformedPost.liked
            (eq this.remainingLikedUsers 0)
          }}
          @count={{if
            this.remainingLikedUsers
            this.remainingLikedUsers
            this.totalLikedUsers
          }}
          @description={{if
            this.remainingLikedUsers
            "post.actions.people.like_capped"
            "post.actions.people.like"
          }}
        />
      {{/if}}
      {{#if this.hasShowMoreButton}}
        <UserTip
          @id="post_menu"
          @triggerSelector=".post-controls .actions .show-more-actions"
          @placement="top"
          @titleText={{i18n "user_tips.post_menu.title"}}
          @contentText={{i18n "user_tips.post_menu.content"}}
        />
      {{/if}}
    </section>
  </template>
}
