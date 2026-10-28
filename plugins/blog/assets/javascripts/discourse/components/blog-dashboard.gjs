import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import DiscourseURL, { searchParamsFromPath } from "discourse/lib/url";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import DLoadMore from "discourse/ui-kit/d-load-more";
import DPageHeader from "discourse/ui-kit/d-page-header";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import {
  editorFilters,
  STATUS_OPTIONS,
} from "discourse/plugins/blog/discourse/lib/blog-editor-filters";

export default class BlogDashboard extends Component {
  @service composer;
  @service currentUser;
  @service router;
  @service siteSettings;

  @tracked filter;
  @tracked loading = false;
  @tracked loadingMore = false;
  @tracked page = 0;
  @tracked query;
  // Lets a newer filter change discard responses to older ones.
  #requestId = 0;

  @tracked _data;

  constructor() {
    super(...arguments);
    const { filter, q } = editorFilters(
      Object.fromEntries(searchParamsFromPath(this.router.currentURL))
    );
    this.filter = filter;
    this.query = q;
  }

  get data() {
    return this._data || this.args.model;
  }

  get showEmptyState() {
    return (
      !this.topics.length &&
      !this.loading &&
      this.filter === "all" &&
      !this.query
    );
  }

  get topics() {
    return this.data?.topics || [];
  }

  @action
  async newDraft() {
    const category = Category.findById(this.siteSettings.blog_drafts_category);
    await this.composer.openNewTopic({ category });
  }

  @action
  onQueryChange(event) {
    this.query = editorFilters({ q: event.target.value }).q;
    discourseDebounce(this, this.#load, INPUT_DELAY);
  }

  @action
  onStatusFilterChange(filter) {
    this.filter = filter;
    this.#load();
  }

  @action
  async onResetFilters() {
    this.filter = "all";
    this.query = "";
    await this.#load();
  }

  @action
  async loadMore() {
    if (this.loading || this.loadingMore || !this.data.more) {
      return;
    }
    const requestId = this.#requestId;
    this.loadingMore = true;
    try {
      const data = await ajax("/blog-editor.json", {
        data: { page: this.page + 1, filter: this.filter, q: this.query },
      });
      if (requestId !== this.#requestId) {
        return;
      }
      this.page += 1;
      this._data = {
        ...data,
        topics: [
          ...new Map(
            [...this.data.topics, ...data.topics].map((topic) => [
              topic.id,
              topic,
            ])
          ).values(),
        ],
      };
    } catch (error) {
      if (requestId === this.#requestId) {
        popupAjaxError(error);
      }
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  async editPrivately(topic) {
    try {
      const publication = await ajax(
        `/blog-editor/publications/${topic.id}/prepare.json`,
        { type: "POST" }
      );
      DiscourseURL.routeTo(publication.source_url);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #load() {
    const requestId = ++this.#requestId;
    this.loading = true;
    try {
      const data = await ajax("/blog-editor.json", {
        data: { filter: this.filter, q: this.query },
      });
      if (requestId === this.#requestId) {
        this._data = data;
        this.page = 0;
      }
    } catch (error) {
      if (requestId === this.#requestId) {
        popupAjaxError(error);
      }
    } finally {
      if (requestId === this.#requestId) {
        this.loading = false;
      }
    }
  }

  <template>
    <div class="blog-dashboard" ...attributes>
      <DPageHeader
        @collapseActionsOnMobile={{false}}
        @descriptionLabel={{i18n "blog.editor_description"}}
        @titleLabel={{i18n "blog.editor_title"}}
      >
        <:actions>
          <DButton
            class="btn-primary"
            @action={{this.newDraft}}
            @disabled={{this.data.error}}
            @icon="pen-to-square"
            @label="blog.new_draft"
          />
        </:actions>
      </DPageHeader>
      {{#if this.data.error}}
        <DFlashMessage @flash={{this.data.error}} @type="warning" />
        <a href="/admin/site_settings/category/plugins?filter=blog_">{{i18n
            "blog.settings"
          }}</a>
      {{/if}}
      <div class="blog-dashboard__links">
        {{#if this.currentUser.admin}}<a
            href="/admin/plugins/blog/themes"
          >{{i18n "blog.appearance_link"}}</a>{{/if}}
        <a
          href={{this.data.blog_url}}
          rel="noopener noreferrer"
          target="_blank"
        >{{i18n "blog.visit_blog"}} ↗</a>
      </div>
      <p class="blog-dashboard__hint">{{i18n "blog.drafts_hint"}}</p>
      <DFilterControls
        @array={{this.topics}}
        @dropdownFilterQueryParam="status"
        @dropdownOptions={{STATUS_OPTIONS}}
        @dropdownValue={{this.filter}}
        @initialTextFilter={{this.query}}
        @inputPlaceholder={{i18n "blog.editor_search_hint"}}
        @loading={{this.loading}}
        @noResultsMessage={{i18n "blog.editor_no_results"}}
        @onDropdownFilterChange={{this.onStatusFilterChange}}
        @onResetFilters={{this.onResetFilters}}
        @onTextFilterChange={{this.onQueryChange}}
        @textFilterQueryParam="q"
      >
        <:content>
          <DLoadMore
            class="blog-dashboard__load-more"
            @action={{this.loadMore}}
            @enabled={{this.data.more}}
            @isLoading={{this.loadingMore}}
            @rootMargin="0px 0px 250px 0px"
          >
            <table class="d-table blog-dashboard__table">
              <thead class="d-table__header">
                <tr class="d-table__row">
                  <th class="d-table__header-cell">{{i18n
                      "blog.editor_table.article"
                    }}</th>
                  <th class="d-table__header-cell">{{i18n
                      "blog.editor_table.status"
                    }}</th>
                  <th class="d-table__header-cell">{{i18n
                      "blog.editor_table.published"
                    }}</th>
                  <th class="d-table__header-cell">{{i18n
                      "blog.editor_table.replies"
                    }}</th>
                  <th class="d-table__header-cell"></th>
                </tr>
              </thead>
              <tbody class="d-table__body">
                {{#each this.topics as |topic|}}
                  <tr
                    class="d-table__row blog-dashboard__row"
                    data-topic-id={{topic.id}}
                  >
                    <td class="d-table__cell --overview">
                      {{#if topic.live}}
                        <a
                          class="d-table__overview-link"
                          href={{or topic.discussion_url topic.url}}
                        >
                          <div class="d-table__overview-name">{{or
                              topic.public_title
                              topic.title
                            }}</div>
                        </a>
                        {{#if topic.public_excerpt}}
                          <p
                            class="blog-dashboard__excerpt"
                          >{{topic.public_excerpt}}</p>
                        {{/if}}
                      {{else}}
                        <a
                          class="d-table__overview-link"
                          href={{topic.topic_url}}
                        >
                          <div
                            class="d-table__overview-name"
                          >{{topic.title}}</div>
                        </a>
                        {{#if topic.excerpt}}
                          <p
                            class="blog-dashboard__excerpt"
                          >{{topic.excerpt}}</p>
                        {{/if}}
                      {{/if}}
                    </td>
                    <td class="d-table__cell --detail">
                      <div class="d-table__mobile-label">{{i18n
                          "blog.editor_table.status"
                        }}</div>
                      <div class="blog-dashboard__statuses">
                        <div
                          class={{dConcatClass
                            "status-label"
                            "blog-dashboard__status"
                            (if topic.live "--success")
                            (unless (or topic.live topic.draft) "--inactive")
                          }}
                        >
                          <div class="status-label-indicator"></div>
                          <div class="status-label-text">{{#if
                              topic.draft
                            }}{{i18n "blog.private_draft"}}{{else if
                              topic.live
                            }}{{i18n "blog.published"}}{{else}}{{i18n
                                "blog.not_published"
                              }}{{/if}}</div>
                        </div>
                        {{#if topic.scheduled_at}}
                          <span class="blog-dashboard__scheduled">{{i18n
                              "blog.editor_table.scheduled"
                            }}</span>
                        {{/if}}
                        {{#if topic.draft_correction}}
                          <span class="blog-dashboard__correction">{{i18n
                              "blog.draft_correction"
                            }}</span>
                        {{/if}}
                      </div>
                    </td>
                    <td
                      class="d-table__cell --detail blog-dashboard__published"
                    >
                      <div class="d-table__mobile-label">{{i18n
                          "blog.editor_table.published"
                        }}</div>
                      {{#if topic.published}}
                        {{dAgeWithTooltip topic.published_at format="medium"}}
                      {{else}}
                        —
                      {{/if}}
                    </td>
                    <td class="d-table__cell --detail blog-dashboard__replies">
                      <div class="d-table__mobile-label">{{i18n
                          "blog.editor_table.replies"
                        }}</div>
                      {{#if
                        topic.discussion_url
                      }}{{topic.replies}}{{else}}—{{/if}}
                    </td>
                    <td class="d-table__cell --controls">
                      <div class="d-table__cell-actions">
                        {{#if topic.source_url}}
                          <DButton
                            class="btn-default btn-small blog-dashboard__edit-private"
                            @href={{topic.source_url}}
                            @label="blog.editor_table.edit"
                          />
                        {{else}}
                          <DButton
                            class="btn-default btn-small blog-dashboard__edit-private"
                            @action={{fn this.editPrivately topic}}
                            @label="blog.editor_table.edit"
                          />
                        {{/if}}
                        <DMenu
                          @icon="ellipsis-vertical"
                          @identifier="blog-dashboard-actions"
                          @title={{i18n "blog.editor_table.more_actions"}}
                          @triggerClass="btn-default btn-small blog-dashboard__more-actions"
                        >
                          <:content>
                            <DDropdownMenu as |dropdown|>
                              {{#if
                                (or topic.draft_correction (not topic.live))
                              }}
                                <dropdown.item>
                                  <DButton
                                    class="btn-transparent blog-dashboard__preview"
                                    rel="noopener noreferrer"
                                    target="_blank"
                                    @href={{topic.preview_url}}
                                    @icon="far-eye"
                                    @label={{if
                                      topic.live
                                      "blog.editor_table.preview_changes"
                                      "blog.preview"
                                    }}
                                  />
                                </dropdown.item>
                              {{/if}}
                              {{#if topic.live}}
                                <dropdown.item>
                                  <DButton
                                    class="btn-transparent blog-dashboard__view-live"
                                    rel="noopener noreferrer"
                                    target="_blank"
                                    @href={{topic.url}}
                                    @icon="up-right-from-square"
                                    @label="blog.editor_table.view_on_blog"
                                  />
                                </dropdown.item>
                              {{/if}}
                              {{#if
                                (and topic.discussion_url (not topic.live))
                              }}
                                <dropdown.item>
                                  <DButton
                                    class="btn-transparent blog-dashboard__discussion"
                                    @href={{topic.discussion_url}}
                                    @icon="comments"
                                    @label="blog.public_discussion"
                                  />
                                </dropdown.item>
                              {{/if}}
                            </DDropdownMenu>
                          </:content>
                        </DMenu>
                      </div>
                    </td>
                  </tr>
                {{/each}}
              </tbody>
            </table>
          </DLoadMore>
          <DConditionalLoadingSpinner @condition={{this.loadingMore}} />
        </:content>
      </DFilterControls>
      {{#if this.showEmptyState}}
        <DEmptyState
          @body={{i18n "blog.editor_no_results_hint"}}
          @title={{i18n "blog.editor_no_results"}}
        />
      {{/if}}
    </div>
  </template>
}
