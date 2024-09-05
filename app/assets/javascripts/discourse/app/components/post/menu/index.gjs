import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { isEmpty, isPresent } from "@ember/utils";
import { and, eq } from "truth-helpers";
import AdminPostMenu from "discourse/components/admin-post-menu";
import DeleteTopicDisallowedModal from "discourse/components/modal/delete-topic-disallowed";
import SmallUserList from "discourse/components/small-user-list";
import UserTip from "discourse/components/user-tip";
import concatClass from "discourse/helpers/concat-class";
import DAG from "discourse/lib/dag";
import { userPath } from "discourse/lib/url";
import i18n from "discourse-common/helpers/i18n";
import discourseLater from "discourse-common/lib/later";
import PostMenuAdminButton from "./buttons/admin";
import PostMenuBookmarkButton from "./buttons/bookmark";
import PostMenuCopyLinkButton from "./buttons/copy-link";
import PostMenuDeleteButton, {
  BUTTON_ACTION_MODE_DELETE,
  BUTTON_ACTION_MODE_DELETE_TOPIC,
  BUTTON_ACTION_MODE_RECOVER,
  BUTTON_ACTION_MODE_RECOVER_TOPIC,
  BUTTON_ACTION_MODE_SHOW_FLAG_DELETE,
} from "./buttons/delete";
import PostMenuEditButton from "./buttons/edit";
import PostMenuFlagButton from "./buttons/flag";
import PostMenuLikeButton from "./buttons/like";
import PostMenuReadButton from "./buttons/read";
import PostMenuRepliesButton from "./buttons/replies";
import PostMenuReplyButton from "./buttons/reply";
import PostMenuShareButton from "./buttons/share";
import PostMenuShowMoreButton from "./buttons/show-more";

const LIKE_ACTION = 2;
const VIBRATE_DURATION = 5;

const ADMIN_BUTTON_ID = "admin";
const BOOKMARK_BUTTON_ID = "bookmark";
const COPY_LINK_BUTTON_ID = "copyLink";
const DELETE_BUTTON_ID = "delete";
const EDIT_BUTTON_ID = "edit";
const FLAG_BUTTON_ID = "flag";
const LIKE_BUTTON_ID = "like";
const READ_BUTTON_ID = "read";
const REPLIES_BUTTON_ID = "replies";
const REPLY_BUTTON_ID = "reply";
const SHARE_BUTTON_ID = "share";
const SHOW_MORE_BUTTON_ID = "showMore";

let registeredButtonComponents;
resetPostMenuButtons();

function resetPostMenuButtons() {
  registeredButtonComponents = new Map(
    [
      [ADMIN_BUTTON_ID, PostMenuAdminButton],
      [BOOKMARK_BUTTON_ID, PostMenuBookmarkButton],
      [COPY_LINK_BUTTON_ID, PostMenuCopyLinkButton],
      [DELETE_BUTTON_ID, PostMenuDeleteButton],
      [EDIT_BUTTON_ID, PostMenuEditButton],
      [FLAG_BUTTON_ID, PostMenuFlagButton],
      [LIKE_BUTTON_ID, PostMenuLikeButton],
      [READ_BUTTON_ID, PostMenuReadButton],
      [REPLIES_BUTTON_ID, PostMenuRepliesButton],
      [REPLY_BUTTON_ID, PostMenuReplyButton],
      [SHARE_BUTTON_ID, PostMenuShareButton],
      [SHOW_MORE_BUTTON_ID, PostMenuShowMoreButton],
    ].map(([id, Button]) => [id, registeredAttributes(Button)])
  );
}

export function clearExtraPostMenuButtons() {
  resetPostMenuButtons();
}

export const _postMenuPluginApi = Object.freeze({
  add(id, component, position) {
    if (registeredButtonComponents.has(id)) {
      return false;
    }

    registeredButtonComponents.set(
      id,
      registeredAttributes(component, position)
    );

    return true;
  },
  delete(id) {
    return registeredButtonComponents.delete(id);
  },
  replace(id, component) {
    const existing = registeredButtonComponents.get(id);
    if (!existing) {
      return false;
    }

    registeredButtonComponents.set(id, { ...existing, component });

    return true;
  },
  reposition(id, position) {
    const existing = registeredButtonComponents.get(id);
    if (!existing) {
      return false;
    }

    registeredButtonComponents.set(id, { ...existing, position });

    return true;
  },
  has(id) {
    return registeredButtonComponents.has(id);
  },
});

function registeredAttributes(ButtonComponent, position) {
  return {
    Component: ButtonComponent,
    position,
  };
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
  @service modal;
  @service menu;
  @service site;
  @service siteSettings;
  @service store;

  @tracked collapsed = true; // TODO some plugins will need a value transformer
  @tracked likedUsers = [];
  @tracked totalLikedUsers;
  @tracked readers = [];
  @tracked totalReaders;

  @cached
  get registeredButtons() {
    return new Map(
      registeredButtonComponents.entries().map(([id, attributes]) => {
        let alwaysShow = false;
        let extraControl = false;
        let actionMode;
        let primaryAction;
        let secondaryAction;
        let properties;

        switch (id) {
          case ADMIN_BUTTON_ID:
            primaryAction = this.openAdminMenu;
            break;

          case COPY_LINK_BUTTON_ID:
            primaryAction = this.args.copyLink;
            break;

          case DELETE_BUTTON_ID:
            if (this.args.post.canRecoverTopic) {
              actionMode = BUTTON_ACTION_MODE_RECOVER_TOPIC;
              primaryAction = this.args.recoverPost;
            } else if (this.args.post.canDeleteTopic) {
              actionMode = BUTTON_ACTION_MODE_DELETE_TOPIC;
              primaryAction = this.args.deletePost;
            } else if (this.args.post.canRecover) {
              actionMode = BUTTON_ACTION_MODE_RECOVER;
              primaryAction = this.args.recoverPost;
            } else if (this.args.post.canDelete) {
              actionMode = BUTTON_ACTION_MODE_DELETE;
              primaryAction = this.args.deletePost;
            } else if (this.args.post.showFlagDelete) {
              actionMode = BUTTON_ACTION_MODE_SHOW_FLAG_DELETE;
              primaryAction = this.showDeleteTopicModal;
            }
            break;

          case EDIT_BUTTON_ID:
            primaryAction = this.args.editPost;
            alwaysShow =
              this.#isWikiMode ||
              (this.args.post.can_edit && this.args.post.yours);
            properties = {
              showLabel: this.site.desktopView && this.#isWikiMode,
            };
            break;

          case FLAG_BUTTON_ID:
            primaryAction = this.args.showFlags;
            break;

          case LIKE_BUTTON_ID:
            primaryAction = this.like;
            secondaryAction = this.toggleWhoLiked;
            break;

          case READ_BUTTON_ID:
            primaryAction = this.toggleWhoRead;
            properties = { showReadIndicator: this.args.showReadIndicator };
            break;

          case REPLY_BUTTON_ID:
            primaryAction = this.args.replyToPost;
            properties = {
              canCreatePost: this.args.canCreatePost,
              showLabel: this.site.desktopView && !this.#isWikiMode,
            };
            break;

          case REPLIES_BUTTON_ID:
            extraControl = true;
            primaryAction = this.args.toggleReplies;
            properties = {
              filteredRepliesView: this.args.filteredRepliesView,
              replyDirectlyBelow:
                this.args.nextPost?.reply_to_post_number ===
                  this.args.post.post_number &&
                this.args.post.post_number !==
                  this.args.post.filteredRepliesPostNumber,
            };
            break;

          case SHARE_BUTTON_ID:
            primaryAction = this.args.share;
            break;

          case SHOW_MORE_BUTTON_ID:
            primaryAction = this.showMoreActions;
            break;
        }

        const config = {
          id,
          Component: attributes.Component,
          position: {
            before: attributes.position?.before,
            after: attributes.position?.after,
          },
          action: primaryAction,
          secondaryAction,
          actionMode,
          alwaysShow,
          properties,
          extraControl: attributes.position?.extraControl ?? extraControl,
        };

        return [id, config];
      })
    );
  }

  get items() {
    const list = this.#configuredItems.map((i) => {
      // if the post is a wiki, make Edit more prominent
      if (this.#isWikiMode) {
        switch (i) {
          case EDIT_BUTTON_ID:
            return REPLY_BUTTON_ID;
          case REPLY_BUTTON_ID:
            return EDIT_BUTTON_ID;
        }
      }

      return i;
    });

    if (list.length > 0 && !list.includes(SHOW_MORE_BUTTON_ID)) {
      list.splice(list.length - 1, 0, SHOW_MORE_BUTTON_ID);
    }

    return list;
  }

  @cached
  get extraControls() {
    const items = [REPLIES_BUTTON_ID];

    return items
      .map((itemId) => this.registeredButtons.get(itemId))
      .filter((button) => isPresent(button) && button.extraControl);
  }

  get availableButtons() {
    return this.items
      .map((itemId) => this.registeredButtons.get(itemId))
      .filter((button) => isPresent(button) && !button.extraControl);
  }

  @cached
  get collapsedButtons() {
    const hiddenItems = this.#hiddenItems;

    if (
      isEmpty(hiddenItems) ||
      !this.collapsed ||
      !this.availableButtons.some((button) => button.id === SHOW_MORE_BUTTON_ID)
    ) {
      return [];
    }

    return this.availableButtons.filter((button) => {
      if (button.alwaysShow || button.id === SHOW_MORE_BUTTON_ID) {
        return false;
      }

      if (this.args.post.reviewable_id && button.id === FLAG_BUTTON_ID) {
        return false;
      }

      return hiddenItems.includes(button.id);
    });
  }

  @cached
  get visibleButtons() {
    const nonCollapsed = this.availableButtons.filter((button) => {
      return !this.collapsedButtons.includes(button);
    });

    const dag = new DAG();
    new Set(nonCollapsed).forEach((button) =>
      dag.add(button.id, button, button.position)
    );

    return dag.resolve().map(({ value }) => value);
  }

  get repliesButton() {
    return this.registeredButtons.get(REPLIES_BUTTON_ID);
  }

  get isShowMoreButtonVisible() {
    // Only show ellipsis if there is more than one button hidden
    // if there are no more buttons, we are not collapsed
    return this.collapsedButtons.length > 1;
  }

  get showMoreButton() {
    return this.registeredButtons.get(SHOW_MORE_BUTTON_ID);
  }

  get remainingLikedUsers() {
    return this.totalLikedUsers - this.likedUsers.length;
  }

  get remainingReaders() {
    return this.totalReaders - this.readers.length;
  }

  @action
  async like({ onBeforeToggle } = {}) {
    if (!this.currentUser) {
      this.keyValueStore &&
        this.keyValueStore.set({
          key: "likedPostId",
          value: this.args.post.id,
        });
      return this.sendWidgetAction("showLogin");
    }

    if (this.capabilities.userHasBeenActive && this.capabilities.canVibrate) {
      navigator.vibrate(VIBRATE_DURATION);
    }

    if (this.args.post.liked) {
      return this.args.toggleLike();
    }

    onBeforeToggle?.(this.args.post.liked);

    return new Promise((resolve) => {
      discourseLater(async () => {
        await this.args.toggleLike();
        resolve();
      }, 400);
    });
  }

  @action
  openAdminMenu(_, event) {
    this.menu.show(event.target, {
      identifier: "admin-post-menu",
      component: AdminPostMenu,
      modalForMobile: true,
      autofocus: true,
      data: {
        post: this.args.post,
        changeNotice: this.args.changeNotice,
        changePostOwner: this.args.changePostOwner,
        grantBadge: this.args.grantBadge,
        lockPost: this.args.lockPost,
        permanentlyDeletePost: this.args.permanentlyDeletePost,
        rebakePost: this.args.rebakePost,
        showPagePublish: this.args.showPagePublish,
        togglePostType: this.args.togglePostType,
        toggleWiki: this.args.toggleWiki,
        unhidePost: this.args.unhidePost,
        unlockPost: this.args.unlockPost,
      },
    });
  }

  @action
  showDeleteTopicModal() {
    this.modal.show(DeleteTopicDisallowedModal);
  }

  @action
  async showMoreActions() {
    this.collapsed = false;

    const fetchData = [
      !this.likedUsers.length && this.#fetchWhoLiked(),
      !this.readers.length &&
        this.args.showReadIndicator &&
        this.#fetchWhoRead(),
    ].filter(Boolean);

    await Promise.all(fetchData);
  }

  @action
  toggleWhoLiked() {
    if (this.likedUsers.length) {
      this.likedUsers = [];
      this.totalLikedUsers = null;
      return;
    }

    this.#fetchWhoLiked();
  }

  @action
  toggleWhoRead() {
    if (this.readers.length) {
      this.readers = [];
      this.totalReaders = null;
      return;
    }

    this.#fetchWhoRead();
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
        (itemId) => !this.args.post.bookmarked || itemId !== BOOKMARK_BUTTON_ID
      );
  }

  get #isWikiMode() {
    return this.args.post.wiki && this.args.post.can_edit;
  }

  async #fetchWhoLiked() {
    const users = await this.store.find("post-action-user", {
      id: this.args.post.id,
      post_action_type_id: LIKE_ACTION,
    });

    this.likedUsers = users.map(smallUserAttributes);
    this.totalLikedUsers = users.totalRows;
  }

  async #fetchWhoRead() {
    const users = await this.store.find("post-reader", {
      id: this.args.post.id,
    });

    this.readers = users.map(smallUserAttributes);
    this.totalReaders = users.totalRows;
  }

  <template>
    <section class="post-menu-area clearfix">
      <nav
        class={{concatClass
          "post-controls"
          (if
            (and this.isShowMoreButtonVisible this.collapsed)
            "collapsed"
            "expanded"
          )
          (if
            this.siteSettings.enable_filtered_replies_view
            "replies-button-visible"
          )
        }}
      >
        {{! do not include PluginOutlets here, use the PostMenu DAG API instead }}
        {{#each this.extraControls as |extraControl|}}
          <extraControl.Component
            class="btn-flat"
            @post={{@post}}
            @properties={{extraControl.properties}}
            @action={{extraControl.action}}
            @actionMode={{extraControl.actionMode}}
            @secondaryAction={{extraControl.secondaryAction}}
          />
        {{/each}}
        <div class="actions">
          {{#each this.visibleButtons as |button|}}
            <button.Component
              class="btn-flat"
              @post={{@post}}
              @properties={{button.properties}}
              @action={{button.action}}
              @actionMode={{button.actionMode}}
              @secondaryAction={{button.secondaryAction}}
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
          @addSelf={{and @post.liked (eq this.remainingLikedUsers 0)}}
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
      {{#if this.isShowMoreButtonVisible}}
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
