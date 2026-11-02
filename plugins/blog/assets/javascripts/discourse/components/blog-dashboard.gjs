import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
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

// "Changes pending" is still a live article; the edits are shown as separate pending work.
function articleState(topic) {
  return topic.status === "changes_pending" ? "live" : topic.status;
}

function pendingWork(topic) {
  if (topic.awaiting_approval) {
    return i18n(
      topic.published
        ? "blog.editor_table.edits_need_approval"
        : "blog.panel.needs_approval"
    );
  }
  if (topic.status === "changes_pending") {
    return i18n("blog.editor_table.edits_pending");
  }
}

const PendingWork = <template>
  {{#let (pendingWork @topic) as |pending|}}
    {{#if pending}}
      <span class="status-label blog-dashboard__pending">
        <span class="status-label-text">{{pending}}</span>
      </span>
    {{/if}}
  {{/let}}
</template>;

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
        @hideTabs={{true}}
        @titleLabel={{i18n "blog.editor_title"}}
      >
        <:actions as |actions|>
          <actions.Primary
            @action={{this.newDraft}}
            @disabled={{this.data.error}}
            @icon="pen-to-square"
            @label="blog.new_draft"
          />
          <actions.Wrapped>
            <DMenu
              @icon="ellipsis-vertical"
              @identifier="blog-dashboard-page-actions"
              @placement="bottom-end"
              @title={{i18n "blog.editor_table.more_actions"}}
              @triggerClass="btn-default btn-small blog-dashboard__page-actions"
            >
              <:content>
                <DDropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      class="btn-transparent blog-dashboard__visit-blog"
                      rel="noopener noreferrer"
                      target="_blank"
                      @href={{this.data.blog_url}}
                      @icon="up-right-from-square"
                      @label="blog.visit_blog"
                    />
                  </dropdown.item>
                  {{#if this.currentUser.admin}}
                    <dropdown.item>
                      <DButton
                        class="btn-transparent blog-dashboard__appearance"
                        @icon="palette"
                        @label="blog.appearance_link"
                        @route="adminPlugins.show.discourse-blog-themes"
                        @routeModels="blog"
                      />
                    </dropdown.item>
                  {{/if}}
                </DDropdownMenu>
              </:content>
            </DMenu>
          </actions.Wrapped>
        </:actions>
      </DPageHeader>
      {{#if this.data.error}}
        <DFlashMessage @flash={{this.data.error}} @type="warning" />
        <a href="/admin/plugins/blog/settings?filter=category">{{i18n
            "blog.settings"
          }}</a>
      {{/if}}
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
                  <th
                    class="d-table__header-cell blog-dashboard__status-column"
                  >{{i18n "blog.editor_table.status"}}</th>
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
                        <div class="blog-dashboard__title-row">
                          <a
                            class="d-table__overview-link"
                            href={{or topic.discussion_url topic.url}}
                          >
                            <div class="d-table__overview-name">{{or
                                topic.public_title
                                topic.title
                              }}</div>
                          </a>
                          <PendingWork @topic={{topic}} />
                        </div>
                        {{#if topic.public_excerpt}}
                          <p
                            class="blog-dashboard__excerpt"
                          >{{topic.public_excerpt}}</p>
                        {{/if}}
                      {{else}}
                        <div class="blog-dashboard__title-row">
                          <a
                            class="d-table__overview-link"
                            href={{topic.topic_url}}
                          >
                            <div
                              class="d-table__overview-name"
                            >{{topic.title}}</div>
                          </a>
                          <PendingWork @topic={{topic}} />
                        </div>
                        {{#if topic.excerpt}}
                          <p
                            class="blog-dashboard__excerpt"
                          >{{topic.excerpt}}</p>
                        {{/if}}
                      {{/if}}
                    </td>
                    <td
                      class="d-table__cell --detail blog-dashboard__status-column"
                    >
                      <div class="d-table__mobile-label">{{i18n
                          "blog.editor_table.status"
                        }}</div>
                      {{#let (articleState topic) as |state|}}
                        <div
                          class={{dConcatClass
                            "status-label"
                            "blog-dashboard__status"
                            (if (eq state "live") "--success")
                            (if (eq state "unpublished") "--inactive")
                          }}
                        >
                          <div class="status-label-indicator"></div>
                          <div class="status-label-text">{{i18n
                              (concat "blog.panel.badge." state)
                            }}</div>
                        </div>
                      {{/let}}
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
