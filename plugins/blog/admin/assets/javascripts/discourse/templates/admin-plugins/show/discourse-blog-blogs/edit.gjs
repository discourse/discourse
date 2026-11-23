import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DButton from "discourse/ui-kit/d-button";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DNavItem from "discourse/ui-kit/d-nav-item";
import { i18n } from "discourse-i18n";
import {
  removeSiteBlog,
  storeSiteBlog,
} from "discourse/plugins/blog/discourse/lib/site-blogs";

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
          {{/unless}}
          {{#unless this.blog.is_default}}
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
            @label="blog.admin.settings_tab"
            @route="adminPlugins.show.discourse-blog-blogs.edit.settings"
          />
          <DNavItem
            @label="blog.admin.theme_tab"
            @route="adminPlugins.show.discourse-blog-blogs.edit.theme"
          />
        </DHorizontalOverflowNav>
      </div>
      <div class="blog-edit__tab">{{outlet}}</div>
    </div>
  </template>
}
