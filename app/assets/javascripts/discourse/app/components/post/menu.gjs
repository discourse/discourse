import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action, computed } from "@ember/object";
import { getOwner, setOwner } from "@ember/owner";
import { inject as service } from "@ember/service";
import { isEmpty, isPresent } from "@ember/utils";
import { and, eq } from "truth-helpers";
import AdminPostMenu from "discourse/components/admin-post-menu";
import DeleteTopicDisallowedModal from "discourse/components/modal/delete-topic-disallowed";
import SmallUserList from "discourse/components/small-user-list";
import UserTip from "discourse/components/user-tip";
import concatClass from "discourse/helpers/concat-class";
import DAG from "discourse/lib/dag";
import { applyValueTransformer } from "discourse/lib/transformer";
import { userPath } from "discourse/lib/url";
import i18n from "discourse-common/helpers/i18n";
import discourseLater from "discourse-common/lib/later";
import PostMenuButtonConfig from "./menu/button-config";
import PostMenuButtonWrapper from "./menu/button-wrapper";
import PostMenuAdminButton from "./menu/buttons/admin";
import PostMenuBookmarkButton from "./menu/buttons/bookmark";
import PostMenuCopyLinkButton from "./menu/buttons/copy-link";
import PostMenuDeleteButton from "./menu/buttons/delete";
import PostMenuEditButton from "./menu/buttons/edit";
import PostMenuFlagButton from "./menu/buttons/flag";
import PostMenuLikeButton from "./menu/buttons/like";
import PostMenuReadButton from "./menu/buttons/read";
import PostMenuRepliesButton from "./menu/buttons/replies";
import PostMenuReplyButton from "./menu/buttons/reply";
import PostMenuShareButton from "./menu/buttons/share";
import PostMenuShowMoreButton from "./menu/buttons/show-more";

const LIKE_ACTION = 2;
const VIBRATE_DURATION = 5;

export const POST_MENU_ADMIN_BUTTON_KEY = "admin";
export const POST_MENU_BOOKMARK_BUTTON_KEY = "bookmark";
export const POST_MENU_COPY_LINK_BUTTON_KEY = "copyLink";
export const POST_MENU_DELETE_BUTTON_KEY = "delete";
export const POST_MENU_EDIT_BUTTON_KEY = "edit";
export const POST_MENU_FLAG_BUTTON_KEY = "flag";
export const POST_MENU_LIKE_BUTTON_KEY = "like";
export const POST_MENU_READ_BUTTON_KEY = "read";
export const POST_MENU_REPLIES_BUTTON_KEY = "replies";
export const POST_MENU_REPLY_BUTTON_KEY = "reply";
export const POST_MENU_SHARE_BUTTON_KEY = "share";
export const POST_MENU_SHOW_MORE_BUTTON_KEY = "showMore";

const coreButtonComponents = new Map([
  [POST_MENU_ADMIN_BUTTON_KEY, PostMenuAdminButton],
  [POST_MENU_BOOKMARK_BUTTON_KEY, PostMenuBookmarkButton],
  [POST_MENU_COPY_LINK_BUTTON_KEY, PostMenuCopyLinkButton],
  [POST_MENU_DELETE_BUTTON_KEY, PostMenuDeleteButton],
  [POST_MENU_EDIT_BUTTON_KEY, PostMenuEditButton],
  [POST_MENU_FLAG_BUTTON_KEY, PostMenuFlagButton],
  [POST_MENU_LIKE_BUTTON_KEY, PostMenuLikeButton],
  [POST_MENU_READ_BUTTON_KEY, PostMenuReadButton],
  [POST_MENU_REPLIES_BUTTON_KEY, PostMenuRepliesButton],
  [POST_MENU_REPLY_BUTTON_KEY, PostMenuReplyButton],
  [POST_MENU_SHARE_BUTTON_KEY, PostMenuShareButton],
  [POST_MENU_SHOW_MORE_BUTTON_KEY, PostMenuShowMoreButton],
]);

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
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service keyValueStore;
  @service modal;
  @service menu;
  @service site;
  @service siteSettings;
  @service store;

  @tracked collapsed = true; // TODO some plugins will need a value transformer
  @tracked isWhoLikedVisible = false;
  @tracked likedUsers = [];
  @tracked totalLikedUsers;
  @tracked isWhoReadVisible = false;
  @tracked readers = [];
  @tracked totalReaders;

  get buttonActions() {
    return {
      copyLink: this.args.copyLink,
      deletePost: this.args.deletePost,
      editPost: this.args.editPost,
      like: this.like,
      openAdminMenu: this.openAdminMenu,
      recoverPost: this.args.recoverPost,
      replyToPost: this.args.replyToPost,
      setCollapsed: (value) => (this.collapsed = value),
      share: this.args.share,
      showDeleteTopicModal: this.showDeleteTopicModal,
      showFlags: this.args.showFlags,
      showMoreActions: this.showMoreActions,
      toggleReplies: this.args.toggleReplies,
      toggleWhoLiked: this.toggleWhoLiked,
      toggleWhoRead: this.toggleWhoRead,
    };
  }

  @cached
  get staticMethodsContext() {
    return {
      canCreatePost: this.args.canCreatePost,
      collapsed: this.collapsed,
      currentUser: this.currentUser,
      filteredRepliesView: this.args.filteredRepliesView,
      isWhoLikedVisible: this.isWhoLikedVisible,
      isWhoReadVisible: this.isWhoReadVisible,
      isWikiMode: this.isWikiMode,
      repliesShown: this.args.repliesShown,
      replyDirectlyBelow:
        this.args.nextPost?.reply_to_post_number ===
          this.args.post.post_number &&
        this.args.post.post_number !== this.args.post.filteredRepliesPostNumber,
      showReadIndicator: this.args.showReadIndicator,
      suppressReplyDirectlyBelow:
        this.siteSettings.suppress_reply_directly_below,
    };
  }

  get staticMethodsArgs() {
    return { context: this.staticMethodsContext, post: this.args.post };
  }

  get context() {
    return {
      ...this.staticMethodsContext,
      collapsedButtons: this.renderableCollapsedButtons,
    };
  }

  @cached
  get registeredButtons() {
    // the DAG is not resolved now, instead we just use the object for convenience to pass a nice DAG API to be used
    // in the value transformer, and the extract the data to be used later to resolve the DAG order
    const buttonsRegistry = applyValueTransformer(
      "post-menu-registered-buttons",
      // TODO auto-generate the position cordinates based on the order of the elements
      DAG.from(coreButtonComponents.entries()),
      this.staticMethodsArgs
    );

    return new Map(
      buttonsRegistry.entries().map(([key, properties, position]) => {
        const config = new PostMenuButtonConfig({
          key,
          Component: properties,
          alwaysShow: properties.alwaysShow,
          extraControls: properties.extraControls,
          shouldRender: properties.shouldRender,
          showLabel: properties.showLabel,
          position,
        });
        setOwner(config, getOwner(this)); // to allow using getOwner in the static functions

        return [key, config];
      })
    );
  }

  get items() {
    const list = this.#configuredItems.map((i) => {
      // if the post is a wiki, make Edit more prominent
      if (this.isWikiMode) {
        switch (i) {
          case POST_MENU_EDIT_BUTTON_KEY:
            return POST_MENU_REPLY_BUTTON_KEY;
          case POST_MENU_REPLY_BUTTON_KEY:
            return POST_MENU_EDIT_BUTTON_KEY;
        }
      }

      return i;
    });

    if (list.length > 0 && !list.includes(POST_MENU_SHOW_MORE_BUTTON_KEY)) {
      list.splice(list.length - 1, 0, POST_MENU_SHOW_MORE_BUTTON_KEY);
    }

    return list;
  }

  @cached
  get extraControls() {
    const repliesButton = this.registeredButtons.get(
      POST_MENU_REPLIES_BUTTON_KEY
    );

    const items = [
      repliesButton,
      ...this.registeredButtons
        .values()
        .filter((button) => isPresent(button) && button.extraControls),
    ].filter(isPresent);

    return DAG.from(
      items.map((button) => [button.key, button, button.position])
    )
      .resolve()
      .map(({ value }) => value);
  }

  get availableButtons() {
    return this.items
      .map((itemKey) => this.registeredButtons.get(itemKey))
      .filter((button) => isPresent(button) && !button.extraControls);
  }

  @cached
  get availableCollapsedButtons() {
    const hiddenItems = this.#hiddenItems;

    if (
      isEmpty(hiddenItems) ||
      !this.collapsed ||
      !(
        // TODO extract this logic to a method
        (
          this.availableButtons.some(
            (button) => button.key === POST_MENU_SHOW_MORE_BUTTON_KEY
          ) ||
          this.extraControls.some(
            (button) => button.key === POST_MENU_SHOW_MORE_BUTTON_KEY
          )
        )
      )
    ) {
      return [];
    }

    const items = this.availableButtons.filter((button) => {
      if (
        button.alwaysShow(this.staticMethodsArgs) ||
        button.key === POST_MENU_SHOW_MORE_BUTTON_KEY
      ) {
        return false;
      }

      if (
        this.args.post.reviewable_id &&
        button.key === POST_MENU_FLAG_BUTTON_KEY
      ) {
        return false;
      }

      return hiddenItems.includes(button.key);
    });

    if (items.length <= 1) {
      return [];
    }

    return items;
  }

  @cached
  get renderableCollapsedButtons() {
    return this.availableCollapsedButtons.filter((button) =>
      button.shouldRender(this.staticMethodsArgs)
    );
  }

  @cached
  get visibleButtons() {
    const nonCollapsed = this.availableButtons.filter((button) => {
      return !this.availableCollapsedButtons.includes(button);
    });

    return DAG.from(
      nonCollapsed.map((button) => [button.key, button, button.position])
    )
      .resolve()
      .map(({ value }) => value);
  }

  get repliesButton() {
    return this.registeredButtons.get(POST_MENU_REPLIES_BUTTON_KEY);
  }

  get showMoreButton() {
    return this.registeredButtons.get(POST_MENU_SHOW_MORE_BUTTON_KEY);
  }

  get remainingLikedUsers() {
    return this.totalLikedUsers - this.likedUsers.length;
  }

  get remainingReaders() {
    return this.totalReaders - this.readers.length;
  }

  get isWikiMode() {
    return this.args.post.wiki && this.args.post.can_edit;
  }

  @action
  async like({ onBeforeToggle } = {}) {
    if (!this.currentUser) {
      this.keyValueStore &&
        this.keyValueStore.set({
          key: "likedPostId",
          value: this.args.post.id,
        });

      this.args.showLogin();
      return;
    }

    if (this.capabilities.userHasBeenActive && this.capabilities.canVibrate) {
      navigator.vibrate(VIBRATE_DURATION);
    }

    if (this.args.post.liked) {
      await this.#toggleLike();
      return;
    }

    onBeforeToggle?.(this.args.post.liked);

    return new Promise((resolve) => {
      discourseLater(async () => {
        await this.#toggleLike();
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
  refreshReaders() {
    if (this.readers.length) {
      return this.#fetchWhoRead();
    }
  }

  @action
  showDeleteTopicModal() {
    this.modal.show(DeleteTopicDisallowedModal);
  }

  @action
  async showMoreActions() {
    this.collapsed = false;

    const fetchData = [
      !this.isWhoLikedVisible && this.#fetchWhoLiked(),
      !this.isWhoReadVisible &&
        this.args.showReadIndicator &&
        this.#fetchWhoRead(),
    ].filter(Boolean);

    await Promise.all(fetchData);
  }

  @action
  toggleWhoLiked() {
    if (this.isWhoLikedVisible) {
      this.isWhoLikedVisible = false;
      return;
    }

    this.#fetchWhoLiked();
  }

  @action
  toggleWhoRead() {
    if (this.isWhoReadVisible) {
      this.isWhoReadVisible = false;
      return;
    }

    this.#fetchWhoRead();
  }

  @action
  async #toggleLike() {
    await this.args.toggleLike();
    if (!this.collapsed) {
      await this.#fetchWhoLiked();
    }
  }

  get #configuredItems() {
    return this.siteSettings.post_menu.split("|").filter(Boolean);
  }

  @computed("args.post.bookmarked")
  get #hiddenItems() {
    const setting = this.siteSettings.post_menu_hidden_items;

    if (isEmpty(setting)) {
      return [];
    }

    return setting
      .split("|")
      .filter(
        (itemKey) =>
          !this.args.post.bookmarked ||
          itemKey !== POST_MENU_BOOKMARK_BUTTON_KEY
      );
  }

  async #fetchWhoLiked() {
    const users = await this.store.find("post-action-user", {
      id: this.args.post.id,
      post_action_type_id: LIKE_ACTION,
    });

    this.likedUsers = users.map(smallUserAttributes);
    this.totalLikedUsers = users.totalRows;
    this.isWhoLikedVisible = true;
  }

  async #fetchWhoRead() {
    const users = await this.store.find("post-reader", {
      id: this.args.post.id,
    });

    this.readers = users.map(smallUserAttributes);
    this.totalReaders = users.totalRows;
    this.isWhoReadVisible = true;
  }

  <template>
    {{! The section tag can't be include while we're still using the widget shim }}
    {{! <section class="post-menu-area clearfix"> }}
    <nav
      class={{concatClass
        "post-controls"
        "glimmer-post-menu"
        (if
          (and
            (this.showMoreButton.shouldRender
              (hash context=this.context post=this.post)
            )
            this.collapsed
          )
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
      {{#each this.extraControls key="key" as |extraControl|}}
        <PostMenuButtonWrapper
          @buttonActions={{this.buttonActions}}
          @buttonConfig={{extraControl}}
          @context={{this.context}}
          @post={{@post}}
        />
      {{/each}}
      <div class="actions">
        {{#each this.visibleButtons key="key" as |button|}}
          <PostMenuButtonWrapper
            @buttonActions={{this.buttonActions}}
            @buttonConfig={{button}}
            @context={{this.context}}
            @post={{@post}}
          />
        {{/each}}
      </div>
    </nav>
    {{#if this.isWhoReadVisible}}
      <SmallUserList
        class="who-read"
        @addSelf={{false}}
        @ariaLabel={{i18n
          "post.actions.people.sr_post_readers_list_description"
        }}
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
        @users={{this.readers}}
      />
    {{/if}}
    {{#if this.isWhoLikedVisible}}
      <SmallUserList
        class="who-liked"
        @addSelf={{and @post.liked (eq this.remainingLikedUsers 0)}}
        @ariaLabel={{i18n
          "post.actions.people.sr_post_likers_list_description"
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
        @users={{this.likedUsers}}
      />
    {{/if}}
    {{#if this.collapsedButtons}}
      <UserTip
        @id="post_menu"
        @triggerSelector=".post-controls .actions .show-more-actions"
        @placement="top"
        @titleText={{i18n "user_tips.post_menu.title"}}
        @contentText={{i18n "user_tips.post_menu.content"}}
      />
    {{/if}}
    {{! </section> }}
  </template>
}
