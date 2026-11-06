import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import SiteSetting from "discourse/admin/models/site-setting";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

const SETTINGS = ["blog_title", "blog_description", "blog_about"];
const PATH_FORMATS = {
  slug: null,
  year_month_slug: "YYYY/MM",
  year_month_day_slug: "YYYY/MM/DD",
};

export default class BlogIdentity extends Component {
  @service site;
  @service toasts;

  @tracked saving = false;

  get formData() {
    const settings = this.args.settings;
    return {
      ...Object.fromEntries(SETTINGS.map((key) => [key, settings[key] || ""])),
      blog_path_format: settings.blog_path_format || "slug",
    };
  }

  get pathFormats() {
    const today = moment.utc();
    const base = this.#blogBase();
    const slug = i18n("blog.admin.path_format_sample_slug");
    return Object.entries(PATH_FORMATS).map(([value, dateFormat]) => ({
      value,
      base,
      date: dateFormat ? `/${today.format(dateFormat)}` : "",
      slug: `/${slug}`,
    }));
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

  // On the forum's own host the path is enough; a separate blog domain is worth showing.
  #blogBase() {
    const url = new URL(this.site.blog_base_url, window.location.origin);
    const path = url.pathname.replace(/\/$/, "");
    return url.host === window.location.host ? path : `${url.host}${path}`;
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
      <Form
        class="blog-identity__form"
        @commitOnSubmit={{false}}
        @data={{this.formData}}
        @onSubmit={{this.save}}
        as |form|
      >
        <AdminConfigAreaCard @heading="blog.admin.identity">
          <:content>
            <form.Section>
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
            </form.Section>
          </:content>
        </AdminConfigAreaCard>
        <AdminConfigAreaCard @heading="blog.admin.article_urls">
          <:content>
            <form.Section>
              <div class="blog-identity__path-formats --radio-cards">
                <form.Field
                  @description={{i18n "blog.admin.path_format_description"}}
                  @format="full"
                  @name="blog_path_format"
                  @title={{i18n "blog.admin.path_format"}}
                  @type="radio-group"
                  @validation="required"
                  as |field|
                >
                  <field.Control as |radioGroup|>
                    {{#each this.pathFormats as |format|}}
                      <radioGroup.Radio @value={{format.value}} as |radio|>
                        <radio.Title>{{i18n
                            (concat "blog.admin.path_formats." format.value)
                          }}</radio.Title>
                        <radio.Description>
                          <span class="blog-identity__path-example">
                            <span
                              class="blog-identity__path-base"
                            >{{format.base}}</span><span
                              class="blog-identity__path-date"
                            >{{format.date}}</span><span>{{format.slug}}</span>
                          </span>
                        </radio.Description>
                      </radioGroup.Radio>
                    {{/each}}
                  </field.Control>
                </form.Field>
              </div>
            </form.Section>
          </:content>
        </AdminConfigAreaCard>
        <form.Actions><form.Submit
            @disabled={{this.saving}}
            @label="blog.admin.save"
          /></form.Actions>
      </Form>
    </div>
  </template>
}
