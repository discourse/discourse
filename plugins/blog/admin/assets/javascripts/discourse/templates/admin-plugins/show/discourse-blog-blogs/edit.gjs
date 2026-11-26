import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavItem from "discourse/ui-kit/d-nav-item";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  removeSiteBlog,
  storeSiteBlog,
} from "discourse/plugins/blog/discourse/lib/site-blogs";

const TAB_DESCRIPTIONS = {
  about: "blog.admin.about_tab_description",
  theme: "blog.admin.theme_tab_description",
  settings: "blog.admin.settings_tab_description",
};

export default class BlogEditPage extends Component {
  @service dialog;
  @service router;
  @service site;
  @service toasts;

  get blog() {
    return this.args.model.blog;
  }

  get deleteUnavailable() {
    return !this.blog.can_delete;
  }

  get currentTab() {
    return this.router.currentRouteName?.split(".").at(-1);
  }

  get tabDescription() {
    const key = TAB_DESCRIPTIONS[this.currentTab];
    return key && i18n(key);
  }

  get onAboutTab() {
    return this.currentTab === "about";
  }

  get onThemeTab() {
    return this.currentTab === "theme";
  }

  get safeUrl() {
    return `${this.blog.base_url}/?blog_safe_mode=1`;
  }

  @action
  togglePublished() {
    const published = !this.blog.published;
    this.dialog.confirm({
      message: i18n(
        published
          ? "blog.admin.publish_blog_confirm"
          : "blog.admin.unpublish_blog_confirm",
        { name: this.blog.name }
      ),
      didConfirm: async () => {
        try {
          const blog = await ajax(
            `/admin/plugins/blog/blogs/${this.blog.id}.json`,
            { type: "PUT", data: { blog: { published } } }
          );
          storeSiteBlog(this.site, blog);
          this.router.refresh();
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  @action
  destroy() {
    this.dialog.deleteConfirm({
      message: i18n("blog.admin.delete_blog_confirm", { name: this.blog.name }),
      didConfirm: async () => {
        try {
          await ajax(`/admin/plugins/blog/blogs/${this.blog.id}.json`, {
            type: "DELETE",
          });
          removeSiteBlog(this.site, this.blog.id);
          this.toasts.success({
            data: { message: i18n("blog.admin.blog_deleted") },
          });
          this.router.transitionTo("adminPlugins.show.discourse-blog-blogs");
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  <template>
    <div class="blog-edit">
      <DBreadcrumbsItem
        @label={{this.blog.name}}
        @path={{concat "/admin/plugins/blog/blogs/" this.blog.id}}
      />
      <div class="blog-edit__top-bar">
        <BackButton
          @label="blog.admin.back_to_blogs"
          @route="adminPlugins.show.discourse-blog-blogs.index"
        />
        <div class="blog-edit__actions">
          {{#unless this.blog.is_default}}
            <DButton
              class="btn-default blog-edit__publish"
              @action={{this.togglePublished}}
              @icon={{if this.blog.published "eye-slash" "eye"}}
              @label={{if
                this.blog.published
                "blog.admin.unpublish_blog"
                "blog.admin.publish_blog"
              }}
            />
            <DButton
              class="btn-danger blog-edit__delete"
              @action={{this.destroy}}
              @disabled={{this.deleteUnavailable}}
              @icon="trash-can"
              @label="blog.admin.delete_blog"
            />
          {{/unless}}
        </div>
      </div>
      <h2 class="blog-edit__title">{{this.blog.name}}</h2>
      <div class="d-nav-submenu">
        <DHorizontalOverflowNav class="d-nav-submenu__tabs blog-edit__nav">
          <DNavItem
            @label="blog.admin.about_tab"
            @route="adminPlugins.show.discourse-blog-blogs.edit.about"
          />
          <DNavItem
            @label="blog.admin.theme_tab"
            @route="adminPlugins.show.discourse-blog-blogs.edit.theme"
          />
          <DNavItem
            @label="blog.admin.settings_tab"
            @route="adminPlugins.show.discourse-blog-blogs.edit.settings"
          />
        </DHorizontalOverflowNav>
      </div>
      <div class="blog-admin-intro">
        <p class="blog-admin-intro__description">{{this.tabDescription}}</p>
        <div class="blog-edit__links">
          {{#if this.onAboutTab}}
            <a
              class="btn btn-transparent btn-small"
              href={{this.blog.base_url}}
              rel="noopener noreferrer"
              target="_blank"
            >{{i18n "blog.admin.open_blog"}}
              {{dIcon "up-right-from-square"}}</a>
            <a
              class="btn btn-transparent btn-small"
              href={{this.safeUrl}}
              rel="noopener noreferrer"
              target="_blank"
            >{{i18n "blog.admin.safe_mode"}}
              {{dIcon "up-right-from-square"}}</a>
          {{else if this.onThemeTab}}
            <LinkTo
              class="btn btn-transparent btn-small"
              @route="adminPlugins.show.discourse-blog-themes"
            >{{i18n "blog.admin.add_or_edit_themes"}}
              {{dIcon "palette"}}</LinkTo>
          {{/if}}
        </div>
      </div>
      <div class="blog-edit__tab">{{outlet}}</div>
    </div>
  </template>
}
