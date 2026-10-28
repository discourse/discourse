import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { Promise } from "rsvp";
import BookmarkActionsDropdown from "discourse/components/bookmark-actions-dropdown";
import BookmarkModal from "discourse/components/modal/bookmark";
import PluginOutlet from "discourse/components/plugin-outlet";
import ActivityCell from "discourse/components/topic-list/item/activity-cell";
import TopicStatus from "discourse/components/topic-status";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { BookmarkFormData } from "discourse/lib/bookmark-form-data";
import {
  openLinkInNewTab,
  shouldOpenInNewTab,
} from "discourse/lib/click-track";
import BulkSelectBookmarksDropdown from "discourse/select-kit/components/bulk-select-bookmarks-dropdown";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dReplaceEmoji from "discourse/ui-kit/helpers/d-replace-emoji";
import dTopicLink from "discourse/ui-kit/helpers/d-topic-link";
import { i18n } from "discourse-i18n";

export default class BookmarkList extends Component {
  @service appEvents;
  @service dialog;
  @service modal;
  @service site;

  #lastChecked = null;

  get canDoBulkActions() {
    return this.args.bulkSelectHelper?.selected.length;
  }

  get selected() {
    return this.args.bulkSelectHelper?.selected;
  }

  get selectedCount() {
    return this.selected?.length || 0;
  }

  get bulkSelectEnabled() {
    return this.args.bulkSelectHelper?.bulkSelectEnabled;
  }

  @action
  removeBookmark(bookmark) {
    return new Promise((resolve, reject) => {
      const deleteBookmark = () => {
        bookmark
          .destroy()
          .then(() => {
            this.appEvents.trigger(
              "bookmarks:changed",
              null,
              bookmark.attachedTo()
            );
            removeValueFromArray(this.args.content, bookmark);
            resolve(true);
          })
          .catch((error) => {
            reject(error);
          });
      };
      if (!bookmark.reminder_at) {
        return deleteBookmark();
      }
      this.dialog.deleteConfirm({
        message: i18n("bookmarks.confirm_delete"),
        didConfirm: () => deleteBookmark(),
        didCancel: () => resolve(false),
      });
    });
  }

  @action
  screenExcerptForExternalLink(event) {
    if (event?.target?.tagName === "A") {
      if (shouldOpenInNewTab(event.target.href)) {
        openLinkInNewTab(event, event.target);
      }
    }
  }

  @action
  editBookmark(bookmark) {
    this.modal.show(BookmarkModal, {
      model: {
        bookmark: new BookmarkFormData(bookmark),
        afterSave: (savedData) => {
          this.appEvents.trigger(
            "bookmarks:changed",
            savedData,
            bookmark.attachedTo()
          );
          this.args.reload();
        },
        afterDelete: () => {
          this.args.reload();
        },
      },
    });
  }

  @action
  clearBookmarkReminder(bookmark) {
    return ajax(`/bookmarks/${bookmark.id}`, {
      type: "PUT",
      data: { reminder_at: null },
    }).then(() => {
      bookmark.set("reminder_at", null);
    });
  }

  @action
  togglePinBookmark(bookmark) {
    bookmark.togglePin().then(this.args.reload);
  }

  @action
  toggleBulkSelect() {
    this.args.bulkSelectHelper?.toggleBulkSelect();
  }

  @action
  selectAll() {
    this.args.bulkSelectHelper.autoAddBookmarksToBulkSelect = true;
    document
      .querySelectorAll("input.bulk-select:not(:checked)")
      .forEach((el) => el.click());
  }

  @action
  clearAll() {
    this.args.bulkSelectHelper.autoAddBookmarksToBulkSelect = false;
    document
      .querySelectorAll("input.bulk-select:checked")
      .forEach((el) => el.click());
  }

  @action
  toggleBookmarkSelection(bookmark, event) {
    const target = event.target;
    const selected = this.selected;

    if (target.checked) {
      addUniqueValueToArray(selected, bookmark);

      if (this.#lastChecked && event.shiftKey) {
        const bulkSelects = Array.from(
            document.querySelectorAll("input.bulk-select")
          ),
          from = bulkSelects.indexOf(target),
          to = bulkSelects.findIndex((el) => el.id === this.#lastChecked.id),
          start = Math.min(from, to),
          end = Math.max(from, to);

        bulkSelects
          .slice(start, end)
          .filter((el) => el.checked !== true)
          .forEach((checkbox) => {
            checkbox.click();
          });
      }
      this.#lastChecked = target;
    } else {
      removeValueFromArray(selected, bookmark);
      this.#lastChecked = null;
    }
  }

  <template>
    <div class="bookmark-list-wrapper" ...attributes>
      <DConditionalLoadingSpinner @condition={{@loading}}>
        <DLoadMore @action={{@loadMore}}>
          <table class="topic-list bookmark-list">
            <thead class="topic-list-header">
              <tr>
                {{#if this.site.desktopView}}
                  <PluginOutlet @name="bookmark-list-table-header">
                    {{#if this.bulkSelectEnabled}}
                      <th class="bulk-select topic-list-data">
                        <DButton
                          class="bulk-select btn-flat"
                          @action={{this.toggleBulkSelect}}
                          @icon="list-check"
                          @title="bookmarks.bulk.toggle"
                        />
                      </th>
                    {{/if}}
                    <th class="topic-list-data">

                      {{#if this.bulkSelectEnabled}}
                        <span class="bulk-select-topics">
                          {{~#if this.canDoBulkActions}}
                            <div class="bulk-select-bookmarks-dropdown">
                              <span
                                class="bulk-select-bookmark-dropdown__count"
                              >
                                {{i18n
                                  "bookmarks.bulk.selected_count"
                                  count=this.selectedCount
                                }}
                              </span>
                              <BulkSelectBookmarksDropdown
                                @bulkSelectHelper={{@bulkSelectHelper}}
                              />
                            </div>

                          {{/if~}}
                          <DButton
                            class="btn btn-default bulk-select-all"
                            @action={{this.selectAll}}
                            @label="bookmarks.bulk.select_all"
                          />
                          <DButton
                            class="btn btn-default bulk-clear-all"
                            @action={{this.clearAll}}
                            @label="bookmarks.bulk.clear_all"
                          />
                        </span>
                      {{else}}
                        <DButton
                          class="btn-flat bulk-select"
                          @action={{this.toggleBulkSelect}}
                          @icon="list-check"
                          @title="bookmarks.bulk.toggle"
                        />
                        {{i18n "topic.title"}}
                      {{/if~}}
                    </th>
                    <th class="topic-list-data">&nbsp;</th>
                    <th class="post-metadata topic-list-data">{{i18n
                        "post.bookmarks.updated"
                      }}</th>
                    <th class="post-metadata topic-list-data">{{i18n
                        "activity"
                      }}</th>
                    <th>&nbsp;</th>
                  </PluginOutlet>
                {{/if}}
              </tr>
            </thead>
            <tbody class="topic-list-body">
              {{#each @content as |bookmark|}}
                <tr
                  class={{dConcatClass
                    "topic-list-item bookmark-list-item"
                    (if bookmark.excerpt "excerpt-expanded" "")
                    (if bookmark.hasMetadata "has-metadata" "")
                  }}
                >
                  {{#if this.bulkSelectEnabled}}
                    <td class="bulk-select bookmark-list-data">
                      <label for="bulk-select-{{bookmark.id}}">
                        <input
                          class="bulk-select"
                          data-id={{bookmark.id}}
                          id="bulk-select-{{bookmark.id}}"
                          type="checkbox"
                          {{on
                            "click"
                            (fn this.toggleBookmarkSelection bookmark)
                          }}
                        />
                      </label>
                    </td>
                  {{/if}}
                  <td class="main-link topic-list-data">
                    <PluginOutlet
                      @name="bookmark-list-before-link"
                      @outletArgs={{lazyHash bookmark=bookmark}}
                    />

                    <span class="link-top-line">
                      {{#if bookmark.hasMetadata}}
                        <div class="bookmark-metadata">
                          {{#if bookmark.reminder_at}}
                            <span
                              class="bookmark-metadata-item bookmark-reminder
                                {{if
                                  bookmark.reminderAtExpired
                                  'bookmark-expired-reminder'
                                }}"
                            >
                              {{dIcon
                                "far-clock"
                              }}{{bookmark.formattedReminder}}
                            </span>
                          {{/if}}
                          {{#if bookmark.name}}
                            <span class="bookmark-metadata-item">
                              {{dIcon "circle-info"}}<span>{{dReplaceEmoji
                                  bookmark.name
                                }}</span>
                            </span>
                          {{/if}}
                        </div>
                      {{/if}}
                      <div class="bookmark-status-with-link">
                        {{#if bookmark.pinned}}
                          {{dIcon "thumbtack" class="bookmark-pinned"}}
                        {{/if}}
                        {{#if bookmark.bookmarkableTopicAlike}}
                          <TopicStatus @topic={{bookmark.topicStatus}} />
                          {{dTopicLink bookmark.topicForList}}
                        {{else}}
                          <a
                            aria-level="2"
                            class="title"
                            href={{bookmark.bookmarkable_url}}
                            role="heading"
                          >
                            {{bookmark.fancy_title}}
                          </a>
                        {{/if}}
                      </div>
                    </span>
                    {{#if bookmark.bookmarkableTopicAlike}}
                      <div class="link-bottom-line">
                        {{dCategoryLink bookmark.category}}
                        <PluginOutlet
                          @name="bookmark-list-tags-wrapper"
                          @outletArgs={{lazyHash
                            bookmark=bookmark
                            tags=bookmark.visibleListTags
                            tagsForUser=@tagsForUser
                          }}
                        >
                          {{dDiscourseTags
                            bookmark
                            mode="list"
                            tagsForUser=@tagsForUser
                          }}
                        </PluginOutlet>
                      </div>
                    {{/if}}
                    {{#if
                      (and
                        this.site.mobileView
                        bookmark.excerpt
                        bookmark.user.avatar_template
                      )
                    }}
                      <a
                        class="avatar"
                        data-user-card={{bookmark.user.username}}
                        href={{bookmark.bookmarkableUser.path}}
                      >
                        {{dAvatar
                          bookmark.bookmarkableUser
                          avatarTemplatePath="avatar_template"
                          usernamePath="username"
                          namePath="name"
                          imageSize="large"
                        }}
                      </a>
                    {{/if}}

                    {{! eslint-disable ember/template-no-invalid-interactive }}
                    {{#if bookmark.excerpt}}
                      <p
                        class="post-excerpt"
                        {{on "click" this.screenExcerptForExternalLink}}
                      >{{trustHTML bookmark.excerpt}}</p>
                    {{/if}}
                  </td>
                  {{#if this.site.desktopView}}
                    <td class="author-avatar topic-list-data">
                      {{#if bookmark.user.avatar_template}}
                        <a
                          class="avatar"
                          data-user-card={{bookmark.user.username}}
                          href={{bookmark.user.path}}
                        >
                          {{dAvatar
                            bookmark.user
                            avatarTemplatePath="avatar_template"
                            usernamePath="username"
                            namePath="name"
                            imageSize="large"
                          }}
                        </a>
                      {{/if}}
                    </td>
                    <td
                      class="post-metadata topic-list-data updated-at"
                    >{{dFormatDate bookmark.updated_at format="tiny"}}</td>
                    <ActivityCell class="post-metadata" @topic={{bookmark}} />
                  {{/if}}
                  <td class="topic-list-data">
                    <BookmarkActionsDropdown
                      @bookmark={{bookmark}}
                      @clearBookmarkReminder={{this.clearBookmarkReminder}}
                      @editBookmark={{this.editBookmark}}
                      @removeBookmark={{this.removeBookmark}}
                      @togglePinBookmark={{this.togglePinBookmark}}
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
          <DConditionalLoadingSpinner @condition={{@loadingMore}} />
        </DLoadMore>
      </DConditionalLoadingSpinner>
    </div>
  </template>
}
