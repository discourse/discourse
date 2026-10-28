import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import DPageHeader from "discourse/ui-kit/d-page-header";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class BlogDashboard extends Component {
  @service composer;
  @service currentUser;
  @service siteSettings;

  @tracked filter = "all";
  @tracked loading = false;
  @tracked page = 0;
  @tracked query = "";
  @tracked _data;

  get data() {
    return this._data || this.args.model;
  }

  get searchData() {
    return { q: this.query };
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
  async setFilter(filter) {
    if (this.loading) {
      return;
    }
    const previousFilter = this.filter;
    this.filter = filter;
    if (!(await this.refresh())) {
      this.filter = previousFilter;
    }
  }

  @action
  async search(data) {
    if (this.loading) {
      return;
    }
    const previousQuery = this.query;
    this.query = data.q?.trim() || "";
    if (!(await this.refresh())) {
      this.query = previousQuery;
    }
  }

  @action
  async refresh() {
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      this._data = await ajax("/blog/editor.json", {
        data: { filter: this.filter, q: this.query },
      });
      this.page = 0;
      return true;
    } catch (error) {
      popupAjaxError(error);
      return false;
    } finally {
      this.loading = false;
    }
  }

  @action
  async loadMore() {
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      const data = await ajax("/blog/editor.json", {
        data: { page: this.page + 1, filter: this.filter, q: this.query },
      });
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
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  @action
  async editPrivately(topic) {
    try {
      const publication = await ajax(
        `/blog/publications/${topic.id}/prepare.json`,
        { type: "POST" }
      );
      DiscourseURL.routeTo(publication.source_url);
    } catch (error) {
      popupAjaxError(error);
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
      <div class="blog-dashboard__toolbar">
        <div class="blog-dashboard__filters">
          <DButton
            class="btn-default"
            @action={{fn this.setFilter "all"}}
            @ariaPressed={{eq this.filter "all"}}
            @disabled={{this.loading}}
            @label="blog.all"
          />
          <DButton
            class="btn-default"
            @action={{fn this.setFilter "drafts"}}
            @ariaPressed={{eq this.filter "drafts"}}
            @disabled={{this.loading}}
            @label="blog.drafts"
          />
          <DButton
            class="btn-default"
            @action={{fn this.setFilter "published"}}
            @ariaPressed={{eq this.filter "published"}}
            @disabled={{this.loading}}
            @label="blog.published"
          />
          <DButton
            class="btn-default"
            @action={{fn this.setFilter "unpublished"}}
            @ariaPressed={{eq this.filter "unpublished"}}
            @disabled={{this.loading}}
            @label="blog.not_published"
          />
        </div>
        <div class="blog-dashboard__links">
          {{#if this.currentUser.admin}}<a
              href="/admin/plugins/blog/themes"
            >{{i18n "blog.appearance_link"}}</a>{{/if}}
          <a
            href={{this.data.blog_url}}
            rel="noopener noreferrer"
            target="_blank"
          >{{i18n "blog.visit_blog"}} ↗</a>
          <DButton
            class="btn-flat"
            @action={{this.refresh}}
            @disabled={{this.loading}}
            @icon="arrows-rotate"
            @title="blog.refresh"
          />
        </div>
      </div>
      <Form
        class="blog-dashboard__search"
        @data={{this.searchData}}
        @onSubmit={{this.search}}
        as |form|
      >
        <form.Field
          @format="full"
          @name="q"
          @showOptional={{false}}
          @title={{i18n "blog.editor_search"}}
          @type="input"
          as |field|
        >
          <field.Control
            maxlength="100"
            placeholder={{i18n "blog.editor_search_hint"}}
            @type="search"
          />
        </form.Field>
        <form.Actions>
          <form.Submit
            @disabled={{this.loading}}
            @label="blog.search_articles"
          />
        </form.Actions>
      </Form>
      <p class="blog-dashboard__hint">{{i18n "blog.editor_pagination_hint"}}</p>
      <p class="blog-dashboard__hint">{{i18n "blog.drafts_hint"}}</p>
      {{#if this.topics.length}}
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
                    <a class="d-table__overview-link" href={{topic.topic_url}}>
                      <div class="d-table__overview-name">{{topic.title}}</div>
                    </a>
                    {{#if topic.excerpt}}
                      <p class="blog-dashboard__excerpt">{{topic.excerpt}}</p>
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
                      <div class="status-label-text">{{#if topic.draft}}{{i18n
                            "blog.private_draft"
                          }}{{else if topic.live}}{{i18n
                            "blog.published"
                          }}{{else}}{{i18n "blog.not_published"}}{{/if}}</div>
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
                <td class="d-table__cell --detail blog-dashboard__published">
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
                  {{#if topic.discussion_url}}{{topic.replies}}{{else}}—{{/if}}
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
                          {{#if (or topic.draft_correction (not topic.live))}}
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
                          {{#if (and topic.discussion_url (not topic.live))}}
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
      {{else}}
        <DEmptyState
          @body={{i18n "blog.editor_no_results_hint"}}
          @title={{i18n "blog.editor_no_results"}}
        />
      {{/if}}
      {{#if this.data.more}}<DButton
          class="btn-default"
          data-blog-load-more
          @action={{this.loadMore}}
          @disabled={{this.loading}}
          @label="blog.load_more"
        />{{/if}}
    </div>
  </template>
}
