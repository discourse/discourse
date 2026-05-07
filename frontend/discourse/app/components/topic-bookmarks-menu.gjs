import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import BookmarkMenu from "discourse/components/bookmark-menu";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import BookmarkModal from "discourse/components/modal/bookmark";
import TopicBookmarkPostSubmenu from "discourse/components/topic-bookmark-post-submenu";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { BookmarkFormData } from "discourse/lib/bookmark-form-data";
import TopicBookmarkManager from "discourse/lib/topic-bookmark-manager";
import DiscourseURL from "discourse/lib/url";
import {
  NO_REMINDER_ICON,
  NOT_BOOKMARKED,
  WITH_REMINDER_ICON,
} from "discourse/models/bookmark";
import { i18n } from "discourse-i18n";

export default class TopicBookmarksMenu extends Component {
  @service modal;
  @service menu;
  @service dialog;
  @service bookmarkApi;
  @service toasts;
  @service currentUser;

  get topic() {
    return this.args.topic;
  }

  get allBookmarks() {
    return this.topic.bookmarks || [];
  }

  get postBookmarks() {
    return this.allBookmarks
      .filter((b) => b.bookmarkable_type === "Post")
      .sort((a, b) => (a.post_number || 0) - (b.post_number || 0));
  }

  get topicBookmark() {
    return this.allBookmarks.find((b) => b.bookmarkable_type === "Topic");
  }

  get hasPostBookmarks() {
    return this.postBookmarks.length > 0;
  }

  get useGroupedDropdown() {
    return this.hasPostBookmarks;
  }

  get isMultipleBookmarks() {
    return this.allBookmarks.length > 1;
  }

  get topicBookmarkManager() {
    return new TopicBookmarkManager(getOwner(this), this.topic);
  }

  get buttonLabel() {
    if (!this.args.showLabel) {
      return;
    }

    if (this.allBookmarks.length >= 1) {
      return i18n("bookmarked.edit_bookmark", {
        count: this.allBookmarks.length,
      });
    } else {
      return i18n("bookmarked.title");
    }
  }

  get buttonIcon() {
    if (this.topicBookmark?.reminder_at) {
      return WITH_REMINDER_ICON;
    } else if (this.topicBookmark) {
      return NO_REMINDER_ICON;
    } else if (this.hasPostBookmarks) {
      return NO_REMINDER_ICON;
    } else {
      return NOT_BOOKMARKED;
    }
  }

  get buttonTitle() {
    if (this.allBookmarks.length === 0) {
      return i18n("bookmarks.not_bookmarked");
    }

    if (this.allBookmarks.length === 1) {
      const bm = this.allBookmarks[0];
      if (bm.reminder_at) {
        return i18n("bookmarks.created_with_reminder_generic", {
          date: new BookmarkFormData(bm).formattedReminder(this.#timezone),
          name: bm.name || "",
        });
      }
      return i18n("bookmarks.created_generic", { name: bm.name || "" });
    }

    return i18n("bookmarked.edit_bookmark", {
      count: this.allBookmarks.length,
    });
  }

  get buttonClasses() {
    const classes = ["bookmark", "widget-button", "bookmark-menu__trigger"];

    if (!this.args.showLabel) {
      classes.push("btn-icon", "no-text");
    } else {
      classes.push("btn-icon-text");
    }

    if (this.args.buttonClasses) {
      classes.push(this.args.buttonClasses);
    }

    if (this.allBookmarks.length > 0) {
      classes.push("bookmarked");
      if (this.allBookmarks.some((b) => b.reminder_at)) {
        classes.push("with-reminder");
      }
      if (!this.topicBookmark) {
        classes.push("--post-bookmarked-only");
      }
    }

    return classes.join(" ");
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  openPostBookmarkSubmenu(bookmark, event) {
    this.menu.show(event.target.closest(".bookmark-menu__row-btn"), {
      identifier: "topic-bookmark-post-submenu",
      component: TopicBookmarkPostSubmenu,
      modalForMobile: true,
      placement: "right-start",
      offset: { mainAxis: 10, crossAxis: -5 },
      data: {
        bookmark,
        onJumpToPost: this.onJumpToPost,
        onEditPostBookmark: this.onEditPostBookmark,
        onRemoveBookmark: this.onRemoveBookmark,
      },
      onClose: () => this.dMenu.close(),
    });
  }

  @action
  async onJumpToPost(bookmark) {
    await this.dMenu.close();
    DiscourseURL.routeTo(this.topic.urlForPostNumber(bookmark.post_number));
  }

  @action
  async onBookmarkTopic() {
    await this.dMenu.close();

    try {
      await this.topicBookmarkManager.create();
      this.toasts.success({
        duration: "short",
        data: { message: i18n("bookmarks.bookmarked_success") },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async onEditTopicBookmark() {
    await this.dMenu.close();

    const bookmark = this.topicBookmark;
    const formData = new BookmarkFormData(bookmark);
    try {
      await this.modal.show(BookmarkModal, {
        model: {
          bookmark: formData,
          afterSave: (savedData) => {
            this.#syncBookmark(savedData.saveData);
            this.topic.set("bookmarked", true);
            this.topic.incrementProperty("bookmarksWereChanged");
            this.topic.appEvents?.trigger(
              "bookmarks:changed",
              savedData.saveData,
              { target: "topic", targetId: bookmark.bookmarkable_id }
            );
          },
          afterDelete: (response, bookmarkId) => {
            this.topic.removeBookmark(bookmarkId);
          },
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async onEditPostBookmark(bookmark) {
    await this.dMenu.close();

    const formData = new BookmarkFormData(bookmark);
    try {
      await this.modal.show(BookmarkModal, {
        model: {
          bookmark: formData,
          afterSave: (savedData) => {
            this.#syncBookmark(savedData.saveData);
            this.topic.set("bookmarked", true);
            this.topic.incrementProperty("bookmarksWereChanged");

            const post = this.topic.postStream?.findLoadedPost(
              bookmark.bookmarkable_id
            );
            if (post) {
              post.createBookmark(savedData.saveData);
            }
          },
          afterDelete: (response, bookmarkId) => {
            this.#removeBookmark(bookmark, bookmarkId, response);
          },
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async onRemoveBookmark(bookmark) {
    try {
      const response = await this.bookmarkApi.delete(bookmark.id);
      this.#removeBookmark(bookmark, bookmark.id, response);
      this.toasts.success({
        duration: "short",
        data: {
          icon: "trash-can",
          message: i18n("bookmarks.deleted_bookmark_success"),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      await this.dMenu.close();
    }
  }

  @action
  async onRemoveTopicBookmark() {
    try {
      const bookmark = this.topicBookmark;
      const response = await this.bookmarkApi.delete(bookmark.id);
      this.topic.removeBookmark(bookmark.id);
      if (response) {
        this.topic.appEvents?.trigger("bookmarks:changed", null, {
          target: "topic",
          targetId: bookmark.bookmarkable_id,
        });
      }
      this.toasts.success({
        duration: "short",
        data: {
          icon: "trash-can",
          message: i18n("bookmarks.deleted_bookmark_success"),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      await this.dMenu.close();
    }
  }

  @action
  async onClearAllBookmarks() {
    await this.dMenu.close();

    this.dialog.yesNoConfirm({
      message: i18n("bookmarks.confirm_clear"),
      didConfirm: () => {
        return this.topic
          .deleteBookmarks()
          .then(() => this.topic.clearBookmarks())
          .catch(popupAjaxError);
      },
    });
  }

  #syncBookmark(data) {
    const existing = this.topic.bookmarks.find((b) => b.id === data.id);
    if (existing) {
      existing.setProperties({
        reminder_at: data.reminder_at,
        name: data.name,
        auto_delete_preference: data.auto_delete_preference,
      });
    }
    this.topic.incrementProperty("bookmarksWereChanged");
  }

  #removeBookmark(bookmark, bookmarkId, response) {
    if (bookmark.bookmarkable_type === "Post") {
      const post = this.topic.postStream?.findLoadedPost(
        bookmark.bookmarkable_id
      );
      if (post) {
        post.deleteBookmark(response?.topic_bookmarked);
      }
    }
    this.topic.removeBookmark(bookmarkId);
  }

  get #timezone() {
    return this.currentUser?.user_option?.timezone || moment.tz.guess();
  }

  <template>
    {{#if this.useGroupedDropdown}}
      <DMenu
        ...attributes
        @identifier="topic-bookmarks-menu"
        class={{this.buttonClasses}}
        @title={{this.buttonTitle}}
        @label={{this.buttonLabel}}
        @icon={{this.buttonIcon}}
        @onRegisterApi={{this.onRegisterApi}}
        @modalForMobile={{true}}
        @arrow={{false}}
      >
        <:content>
          <DropdownMenu as |dropdown|>
            {{! Post bookmark submenu triggers }}
            {{#each this.postBookmarks as |bookmark|}}
              <dropdown.item
                class={{concatClass
                  "bookmark-menu__row --post-bookmark"
                  (if bookmark.name "--has-name")
                }}
                data-menu-option-id="post-{{bookmark.post_number}}"
              >
                <DButton
                  @icon="bookmark"
                  @suffixIcon="angle-right"
                  @translatedAriaLabel={{i18n
                    "bookmarks.post_bookmark"
                    post_number=bookmark.post_number
                  }}
                  @actionParam={{bookmark}}
                  @action={{this.openPostBookmarkSubmenu}}
                  @forwardEvent={{true}}
                  class="bookmark-menu__row-btn"
                >
                  <span class="bookmark-menu__row-texts">
                    <span class="bookmark-menu__row-label">
                      {{i18n
                        "bookmarks.post_bookmark"
                        post_number=bookmark.post_number
                      }}
                    </span>
                    {{#if bookmark.name}}
                      <span class="bookmark-menu__row-description">
                        {{bookmark.name}}
                      </span>
                    {{/if}}
                  </span>
                </DButton>
              </dropdown.item>
            {{/each}}

            {{! Topic bookmark actions }}
            {{#if this.topicBookmark}}
              <dropdown.divider />
              <dropdown.item
                class={{concatClass
                  "bookmark-menu__row --edit"
                  (if this.topicBookmark.name "--has-name")
                }}
                data-menu-option-id="edit-topic-bookmark"
              >
                <DButton
                  @icon="pencil"
                  @action={{this.onEditTopicBookmark}}
                  class="bookmark-menu__row-btn"
                >
                  <span class="bookmark-menu__row-texts">
                    <span class="bookmark-menu__row-label">
                      {{i18n "bookmarks.edit_topic_bookmark"}}
                    </span>
                    {{#if this.topicBookmark.name}}
                      <span class="bookmark-menu__row-description">
                        {{this.topicBookmark.name}}
                      </span>
                    {{/if}}
                  </span>
                </DButton>
              </dropdown.item>
              <dropdown.item
                class="bookmark-menu__row --remove"
                data-menu-option-id="delete-topic-bookmark"
              >
                <DButton
                  @icon="trash-can"
                  @action={{this.onRemoveTopicBookmark}}
                  @label="bookmarks.delete_topic_bookmark"
                  class="bookmark-menu__row-btn --danger"
                />
              </dropdown.item>
            {{else}}
              <dropdown.divider />
              <dropdown.item
                class="bookmark-menu__row --bookmark-topic"
                data-menu-option-id="bookmark-topic"
              >
                <DButton
                  @icon="bookmark"
                  @label="bookmarks.bookmark_topic"
                  @action={{this.onBookmarkTopic}}
                  class="bookmark-menu__row-btn"
                />
              </dropdown.item>
            {{/if}}

            {{! Delete all bookmarks }}
            {{#if this.isMultipleBookmarks}}
              <dropdown.divider />
              <dropdown.item
                class="bookmark-menu__row --remove"
                data-menu-option-id="clear-all"
              >
                <DButton
                  @icon="trash-can"
                  @label="bookmarked.delete_bookmarks"
                  @action={{this.onClearAllBookmarks}}
                  class="bookmark-menu__row-btn --danger"
                />
              </dropdown.item>
            {{/if}}
          </DropdownMenu>
        </:content>
      </DMenu>
    {{else}}
      <BookmarkMenu
        @showLabel={{@showLabel}}
        @bookmarkManager={{this.topicBookmarkManager}}
        @buttonClasses={{@buttonClasses}}
        ...attributes
      />
    {{/if}}
  </template>
}
