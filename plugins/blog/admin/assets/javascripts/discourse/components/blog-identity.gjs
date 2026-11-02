import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import SiteSetting from "discourse/admin/models/site-setting";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default class BlogIdentity extends Component {
  @service site;
  @service toasts;

  @tracked saving = false;

  get formData() {
    const settings = this.args.settings;
    return Object.fromEntries(
      ["blog_title", "blog_description", "blog_about"].map((key) => [
        key,
        settings[key] || "",
      ])
    );
  }

  get safeUrl() {
    return `${this.site.blog_base_url}/?blog_safe_mode=1`;
  }

  @action
  async save(data) {
    this.saving = true;
    try {
      await SiteSetting.bulkUpdate(
        Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, { value }])
        )
      );
      this.toasts.success({
        data: { message: i18n("blog.admin.saved") },
      });
    } catch (error) {
      popupAjaxError(error);
      throw error;
    } finally {
      this.saving = false;
    }
  }

  <template>
    <div class="blog-identity" ...attributes>
      <DBreadcrumbsItem
        @label={{i18n "blog.admin.identity"}}
        @path="/admin/plugins/blog/identity"
      />
      <DPageSubheader
        @descriptionLabel={{i18n "blog.admin.identity_description"}}
        @titleLabel={{i18n "blog.admin.identity"}}
      />
      <div class="blog-identity__links">
        <a
          href={{this.site.blog_base_url}}
          rel="noopener noreferrer"
          target="_blank"
        >{{i18n "blog.admin.open_blog"}} ↗</a>
        <a
          href={{this.safeUrl}}
          rel="noopener noreferrer"
          target="_blank"
        >{{i18n "blog.admin.safe_mode"}} ↗</a>
      </div>
      <AdminConfigAreaCard @heading="blog.admin.identity">
        <:content>
          <Form
            class="blog-identity__form"
            @commitOnSubmit={{false}}
            @data={{this.formData}}
            @onSubmit={{this.save}}
            as |form|
          >
            <form.Field
              @format="full"
              @name="blog_title"
              @title={{i18n "blog.admin.blog_title"}}
              @type="input"
              @validation="required"
              as |field|
            ><field.Control /></form.Field>
            <form.Field
              @format="full"
              @name="blog_description"
              @title={{i18n "blog.admin.tagline"}}
              @type="textarea"
              as |field|
            ><field.Control @rows={{2}} /></form.Field>

            <form.Field
              @format="full"
              @name="blog_about"
              @title={{i18n "blog.admin.about"}}
              @type="composer"
              as |field|
            ><field.Control @height={{220}} /></form.Field>
            <form.Actions><form.Submit
                @disabled={{this.saving}}
                @label="blog.admin.save"
              /></form.Actions>
          </Form>
        </:content>
      </AdminConfigAreaCard>
    </div>
  </template>
}
