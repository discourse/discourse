import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DFlashMessage from "discourse/ui-kit/d-flash-message";
import DPageHeader from "discourse/ui-kit/d-page-header";
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
      this._data = await ajax("/blog-editor.json", {
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
      const data = await ajax("/blog-editor.json", {
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
        `/blog-editor/publications/${topic.id}/prepare.json`,
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
      {{#each this.topics as |topic|}}
        <article class="blog-dashboard__entry" data-topic-id={{topic.id}}>
          <div class="blog-dashboard__entry-content">
            <div class="blog-dashboard__statuses">
              <span class="blog-dashboard__status">{{#if topic.draft}}{{i18n
                    "blog.private_draft"
                  }}{{else if topic.live}}{{i18n
                    "blog.published"
                  }}{{else}}{{i18n "blog.not_published"}}{{/if}}</span>
              {{#if topic.draft_correction}}<span
                  class="blog-dashboard__correction"
                >{{i18n "blog.draft_correction"}}</span>{{/if}}
            </div>
            {{#if topic.live}}
              <h2><a href={{topic.url}}>{{or
                    topic.public_title
                    topic.title
                  }}</a></h2>
              {{#if topic.public_excerpt}}<p>{{topic.public_excerpt}}</p>{{/if}}
              <span class="blog-dashboard__path">{{or
                  topic.public_path
                  topic.path
                }}</span>
            {{else}}
              <h2><a href={{topic.topic_url}}>{{topic.title}}</a></h2>
              {{#if topic.excerpt}}<p>{{topic.excerpt}}</p>{{/if}}
              <span class="blog-dashboard__path">{{topic.path}}</span>
            {{/if}}
          </div>
          <div class="blog-dashboard__entry-actions">
            {{#if topic.live}}
              <a href={{topic.discussion_url}}>{{i18n
                  "blog.public_discussion"
                }}</a>
            {{else}}
              <a
                href={{topic.preview_url}}
                rel="noopener noreferrer"
                target="_blank"
              >{{i18n "blog.preview"}}</a>
            {{/if}}
            {{#if topic.source_url}}
              <a
                class="btn btn-default blog-dashboard__edit-private"
                href={{topic.source_url}}
              >{{i18n "blog.open_draft"}}</a>
            {{else}}
              <DButton
                class="blog-dashboard__edit-private btn-default"
                @action={{fn this.editPrivately topic}}
                @label="blog.edit_privately"
              />
            {{/if}}
          </div>
        </article>
      {{else}}
        <DEmptyState
          @body={{i18n "blog.editor_no_results_hint"}}
          @title={{i18n "blog.editor_no_results"}}
        />
      {{/each}}
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
