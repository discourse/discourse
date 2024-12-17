import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { isEmpty, isPresent } from "@ember/utils";
import { and, eq } from "truth-helpers";
import AdminPostMenu from "discourse/components/admin-post-menu";
import DeleteTopicDisallowedModal from "discourse/components/modal/delete-topic-disallowed";
import PluginOutlet from "discourse/components/plugin-outlet";
import SmallUserList from "discourse/components/small-user-list";
import UserTip from "discourse/components/user-tip";
import concatClass from "discourse/helpers/concat-class";
import DAG from "discourse/lib/dag";
import { applyMutableValueTransformer } from "discourse/lib/transformer";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";
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

const buttonKeys = Object.freeze({
  ADMIN: "admin",
  BOOKMARK: "bookmark",
  COPY_LINK: "copyLink",
  DELETE: "delete",
  EDIT: "edit",
  FLAG: "flag",
  LIKE: "like",
  READ: "read",
  REPLIES: "replies",
  REPLY: "reply",
  SHARE: "share",
  SHOW_MORE: "showMore",
});

const coreButtonComponents = new Map([
  [buttonKeys.ADMIN, PostMenuAdminButton],
  [buttonKeys.BOOKMARK, PostMenuBookmarkButton],
  [buttonKeys.COPY_LINK, PostMenuCopyLinkButton],
  [buttonKeys.DELETE, PostMenuDeleteButton],
  [buttonKeys.EDIT, PostMenuEditButton],
  [buttonKeys.FLAG, PostMenuFlagButton],
  [buttonKeys.LIKE, PostMenuLikeButton],
  [buttonKeys.READ, PostMenuReadButton],
  [buttonKeys.REPLIES, PostMenuRepliesButton],
  [buttonKeys.REPLY, PostMenuReplyButton],
  [buttonKeys.SHARE, PostMenuShareButton],
  [buttonKeys.SHOW_MORE, PostMenuShowMoreButton],
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

const defaultDagOptions = {
  defaultPosition: { before: buttonKeys.SHOW_MORE },
  throwErrorOnCycle: false,
};

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

  @tracked collapsed = true; // TODO (glimmer-post-menu): Some plugins will need a value transformer
  @tracked isWhoLikedVisible = false;
  @tracked likedUsers = [];
  @tracked totalLikedUsers;
  @tracked isWhoReadVisible = false;
  @tracked readers = [];
  @tracked totalReaders;

  @cached
  get buttonActions() {
    return {
      copyLink: this.args.copyLink,
      deletePost: this.args.deletePost,
      editPost: this.args.editPost,
      toggleLike: this.toggleLike,
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
  get staticMethodsState() {
    return Object.freeze({
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
    });
  }

  @cached
  get staticMethodsArgs() {
    return {
      post: this.args.post,
      state: this.staticMethodsState,
    };
  }

  @cached
  get state() {
    return Object.freeze({
      ...this.staticMethodsState,
      collapsedButtons: this.renderableCollapsedButtons,
    });
  }

  @cached
  get registeredButtons() {
    let addedKeys;
    const replacementMap = new WeakMap();

    const configuredItems = this.configuredItems;
    const configuredPositions = this.configuredPositions;

    // it's important to sort the buttons in the order they were configured, so we can feed them in the correct order
    // to initialize the DAG because the results are affected by the order of the items were added
    const sortedButtons = Array.from(coreButtonComponents.entries()).sort(
      ([keyA], [keyB]) => {
        const indexA = configuredItems.indexOf(keyA);
        const indexB = configuredItems.indexOf(keyB);

        if (indexA === -1) {
          return -1;
        }

        return indexA - indexB;
      }
    );

    const dag = DAG.from(
      Array.from(sortedButtons).map(([key, ButtonComponent]) => {
        const configuredIndex = configuredItems.indexOf(key);

        const position =
          configuredIndex !== -1 ? configuredPositions.get(key) : null;

        return [key, ButtonComponent, position];
      }),
      {
        ...defaultDagOptions,
        // we need to keep track of the buttons that were added by plugins because they won't respect the values in
        // the post_menu setting
        onAddItem(key) {
          addedKeys?.add(key);
        },
        onDeleteItem(key) {
          addedKeys?.delete(key);
        },
        // when an item is replaced, we want the new button to inherit the properties defined by static methods in the
        // original button if they're not defined. To achieve this we keep track of the replacements in a map
        onReplaceItem: (key, newComponent, oldComponent) => {
          if (newComponent !== oldComponent) {
            replacementMap.set(newComponent, oldComponent);
          }
        },
      }
    );

    // the map is initialized here, to ensure only the buttons manipulated by plugins using the API are tracked
    addedKeys = new Set();

    // map to keep track of the labels that should be shown for each button if the plugins wants to override the default
    const buttonLabels = new Map();

    const showMoreButtonPosition = configuredItems.indexOf(
      buttonKeys.SHOW_MORE
    );

    const hiddenButtonKeys = this.configuredItems.filter((key) =>
      this.#hiddenItems.includes(key)
    );

    // the DAG is not resolved now, instead we just use the object for convenience to pass a nice DAG API to be used
    // in the value transformer, and extract the data to be used later to resolve the DAG order
    const buttonsRegistry = applyMutableValueTransformer(
      "post-menu-buttons",
      dag,
      {
        ...this.staticMethodsArgs,
        buttonLabels: {
          hide(key) {
            buttonLabels.set(key, false);
          },
          show(key) {
            buttonLabels.set(key, true);
          },
          default(key) {
            return buttonLabels.delete(key);
          },
        },
        buttonKeys,
        firstButtonKey: this.configuredItems[0],
        lastHiddenButtonKey: hiddenButtonKeys.length
          ? hiddenButtonKeys[hiddenButtonKeys.length - 1]
          : null,
        lastItemBeforeMoreItemsButtonKey:
          showMoreButtonPosition > 0
            ? this.configuredItems[showMoreButtonPosition - 1]
            : null,
        secondLastHiddenButtonKey:
          hiddenButtonKeys.length > 1
            ? hiddenButtonKeys[hiddenButtonKeys.length - 2]
            : null,
      }
    );

    return new Map(
      buttonsRegistry.entries().map(([key, ButtonComponent, position]) => {
        const config = new PostMenuButtonConfig({
          key,
          Component: ButtonComponent,
          apiAdded: addedKeys.has(key), // flag indicating if the button was added using the API
          owner: getOwner(this), // to be passed as argument to the static methods
          position,
          replacementMap,
          showLabel: buttonLabels.get(key),
        });

        return [key, config];
      })
    );
  }

  @cached
  get configuredItems() {
    const list = this.siteSettings.post_menu
      .split("|")
      .filter(Boolean)
      .map((key) => {
        // if the post is a wiki, make Edit more prominent
        if (this.isWikiMode) {
          switch (key) {
            case buttonKeys.EDIT:
              return buttonKeys.REPLY;
            case buttonKeys.REPLY:
              return buttonKeys.EDIT;
          }
        }

        return key;
      });

    if (list.length > 0 && !list.includes(buttonKeys.SHOW_MORE)) {
      list.splice(list.length - 1, 0, buttonKeys.SHOW_MORE);
    }

    return list;
  }

  @cached
  get configuredPositions() {
    let referencePosition = "before";

    const configuredItems = this.configuredItems;

    return new Map(
      configuredItems.map((key, index) => {
        if (key === buttonKeys.SHOW_MORE) {
          referencePosition = "after";
          return [key, null];
        } else if (
          referencePosition === "before" &&
          index < configuredItems.length - 1
        ) {
          return [
            key,
            {
              [referencePosition]: [buttonKeys.SHOW_MORE],
            },
          ];
        } else if (referencePosition === "after" && index > 0) {
          return [
            key,
            {
              [referencePosition]: [buttonKeys.SHOW_MORE],
            },
          ];
        } else {
          return [key, null];
        }
      })
    );
  }

  @cached
  get extraControls() {
    const items = Array.from(this.registeredButtons.values())
      .filter(
        (button) =>
          isPresent(button) && button.extraControls(this.staticMethodsArgs)
      )
      .map((button) => [button.key, button, button.position]);

    return DAG.from(items, defaultDagOptions)
      .resolve()
      .map(({ value }) => value);
  }

  @cached
  get availableButtons() {
    const items = this.configuredItems;

    return Array.from(this.registeredButtons.values()).filter(
      (button) =>
        (button.apiAdded || items.includes(button.key)) &&
        !button.extraControls(this.staticMethodsArgs)
    );
  }

  @cached
  get availableCollapsedButtons() {
    const hiddenItems = this.#hiddenItems;

    if (
      isEmpty(hiddenItems) ||
      !this.collapsed ||
      !this.isShowMoreButtonAvailable
    ) {
      return [];
    }

    const items = this.availableButtons.filter((button) => {
      const hidden = button.hidden(this.staticMethodsArgs);

      // when the value returned by hidden is explicitly false we ignore the hidden items specified in the
      // site setting
      if (hidden === false || button.key === buttonKeys.SHOW_MORE) {
        return false;
      }

      if (this.args.post.reviewable_id && button.key === buttonKeys.FLAG) {
        return false;
      }

      return hidden || hiddenItems.includes(button.key);
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
      nonCollapsed.map((button) => [button.key, button, button.position]),
      defaultDagOptions
    )
      .resolve()
      .map(({ value }) => value);
  }

  get repliesButton() {
    return this.registeredButtons.get(buttonKeys.REPLIES);
  }

  get showMoreButton() {
    return this.registeredButtons.get(buttonKeys.SHOW_MORE);
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

  get isShowMoreButtonAvailable() {
    return (
      this.availableButtons.some(
        (button) => button.key === buttonKeys.SHOW_MORE
      ) ||
      this.extraControls.some((button) => button.key === buttonKeys.SHOW_MORE)
    );
  }

  @action
  async toggleLike() {
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

    await this.args.toggleLike();

    if (!this.collapsed) {
      await this.#fetchWhoLiked();
    }
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

  @cached
  get #hiddenItems() {
    const setting = this.siteSettings.post_menu_hidden_items;

    if (isEmpty(setting)) {
      return [];
    }

    return setting
      .split("|")
      .filter(
        (itemKey) =>
          !this.args.post.bookmarked || itemKey !== buttonKeys.BOOKMARK
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
    <PluginOutlet
      @name="post-menu"
      @outletArgs={{hash post=@post state=this.state}}
    >
      <nav
        {{! this.collapsed is included in the check below because "Show More" button can be overriden to be always visible }}
        class={{concatClass
          "post-controls"
          "glimmer-post-menu"
          (if
            (and
              (this.showMoreButton.shouldRender
                (hash post=this.post state=this.state)
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
            @post={{@post}}
            @state={{this.state}}
          />
        {{/each}}
        <div class="actions">
          {{#each this.visibleButtons key="key" as |button|}}
            <PostMenuButtonWrapper
              @buttonActions={{this.buttonActions}}
              @buttonConfig={{button}}
              @post={{@post}}
              @state={{this.state}}
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
      {{#if
        (this.showMoreButton.shouldRender
          (hash post=this.post state=this.state)
        )
      }}
        <UserTip
          @id="post_menu"
          @triggerSelector=".post-controls .actions .show-more-actions"
          @placement="top"
          @titleText={{i18n "user_tips.post_menu.title"}}
          @contentText={{i18n "user_tips.post_menu.content"}}
        />
      {{/if}}
    </PluginOutlet>
    {{! </section> }}
  </template>
}
