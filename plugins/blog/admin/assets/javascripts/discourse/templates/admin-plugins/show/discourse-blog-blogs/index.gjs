import Component from "@glimmer/component";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import Category from "discourse/models/category";
import DButton from "discourse/ui-kit/d-button";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";

function categoryName(categoryId) {
  return Category.findById(categoryId)?.name;
}

function firstProblem(blog) {
  return blog.problems[0];
}

const SetupEmoji = <template>{{dEmoji "wave"}}</template>;

export default class BlogBlogsIndex extends Component {
  @service currentUser;
  @service router;

  @action
  setUpBlog() {
    this.router.transitionTo(
      "adminPlugins.show.discourse-blog-blogs.edit.about",
      this.args.model.blogs[0].id
    );
  }

  <template>
    <section class="blog-blogs">
      {{#if @model.needs_setup}}
        <DEmptyState
          @body={{i18n "blog.admin.setup_description"}}
          @ctaAction={{this.setUpBlog}}
          @ctaLabel={{i18n "blog.admin.setup_button"}}
          @identifier="blog-setup"
          @svgContent={{SetupEmoji}}
          @title={{i18n
            "blog.admin.setup_title"
            name=this.currentUser.displayName
          }}
        />
      {{else}}
        <div class="blog-admin-intro">
          <p class="blog-admin-intro__description">{{i18n
              "blog.admin.blogs_tab_description"
            }}</p>
          <DPageSubheader>
            <:actions as |actions|>
              <PluginOutlet
                @name="blog-admin-add-blog-button"
                @outletArgs={{lazyHash
                  actions=actions
                  canAddBlog=@model.can_add_blog
                }}
              >
                {{#if @model.can_add_blog}}
                  <actions.Primary
                    @icon="plus"
                    @label="blog.admin.add_blog"
                    @route="adminPlugins.show.discourse-blog-blogs.new"
                  />
                {{/if}}
              </PluginOutlet>
            </:actions>
          </DPageSubheader>
        </div>
        <table class="d-table blog-blogs__table">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell">{{i18n
                  "blog.admin.column_name"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "blog.admin.column_address"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "blog.admin.column_category"
                }}</th>
              <th class="d-table__header-cell">{{i18n
                  "blog.admin.column_status"
                }}</th>
              <th class="d-table__header-cell"></th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each @model.blogs key="id" as |blog|}}
              <tr class="d-table__row blog-blogs__row" data-blog-id={{blog.id}}>
                <td class="d-table__cell --overview">
                  <LinkTo
                    class="d-table__overview-name"
                    @model={{blog.id}}
                    @route="adminPlugins.show.discourse-blog-blogs.edit.about"
                  >{{blog.name}}</LinkTo>
                </td>
                <td class="d-table__cell --detail">
                  <div class="d-table__mobile-label">{{i18n
                      "blog.admin.column_address"
                    }}</div>
                  <a
                    href={{blog.base_url}}
                    rel="noopener noreferrer"
                    target="_blank"
                  >{{blog.base_url}}</a>
                </td>
                <td class="d-table__cell --detail">
                  <div class="d-table__mobile-label">{{i18n
                      "blog.admin.column_category"
                    }}</div>
                  {{categoryName blog.category_id}}
                </td>
                <td class="d-table__cell --detail blog-blogs__status">
                  <div class="d-table__mobile-label">{{i18n
                      "blog.admin.column_status"
                    }}</div>
                  {{#if blog.problems.length}}
                    <span
                      class="status-label --warning"
                      title={{firstProblem blog}}
                    ><span class="status-label-text">{{i18n
                          "blog.admin.needs_attention"
                        }}</span></span>
                  {{else if blog.published}}
                    <span class="status-label --success"><span
                        class="status-label-text"
                      >{{i18n "blog.admin.published_status"}}</span></span>
                  {{else}}
                    <span class="status-label --inactive"><span
                        class="status-label-text"
                      >{{i18n "blog.admin.unpublished_status"}}</span></span>
                  {{/if}}
                </td>
                <td class="d-table__cell --controls">
                  <DButton
                    class="btn-default btn-small blog-blogs__edit"
                    @label="blog.admin.edit"
                    @route="adminPlugins.show.discourse-blog-blogs.edit.about"
                    @routeModels={{blog.id}}
                  />
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{/if}}
    </section>
  </template>
}
