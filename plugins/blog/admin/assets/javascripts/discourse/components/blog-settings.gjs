import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import { i18n } from "discourse-i18n";
import { storeSiteBlog } from "discourse/plugins/blog/discourse/lib/site-blogs";

const PATH_PRESETS = {
  slug: "/{slug}",
  year_month_slug: "/{year}/{month}/{slug}",
  year_month_day_slug: "/{year}/{month}/{day}/{slug}",
};
const PATH_TOKEN = /\{(\w+)\}/g;
const PATH_TOKENS = ["year", "month", "day", "slug", "id"];

export default class BlogSettings extends Component {
  @service router;
  @service site;
  @service siteSettings;
  @service toasts;

  @tracked saving = false;

  get formData() {
    const blog = this.args.blog;
    const format = blog.path_format || PATH_PRESETS.slug;
    const preset = Object.keys(PATH_PRESETS).find(
      (key) => PATH_PRESETS[key] === format
    );
    return {
      slug: blog.slug,
      url: blog.url || "",
      category_id: blog.category_id,
      posts_per_page: blog.posts_per_page,
      path_format: preset || "custom",
      custom_path_format: preset ? "" : format,
    };
  }

  // A blog that already has its own domain can still clear it.
  get showsOwnDomain() {
    return this.siteSettings.blog_custom_domains_enabled || this.args.blog.url;
  }

  get pathFormats() {
    return Object.entries(PATH_PRESETS).map(([value, template]) => ({
      value,
      example: this.pathExample(template),
    }));
  }

  get blogBase() {
    // On the forum's own host the path is enough; a separate blog domain is worth showing.
    const url = new URL(this.args.blog.base_url, window.location.origin);
    const path = url.pathname.replace(/\/$/, "");
    return url.host === window.location.host ? path : `${url.host}${path}`;
  }

  @action
  pathExample(template) {
    const today = moment.utc();
    const values = {
      year: today.format("YYYY"),
      month: today.format("MM"),
      day: today.format("DD"),
      slug: i18n("blog.admin.path_format_sample_slug"),
      id: "123",
    };
    return (template || "").replace(
      PATH_TOKEN,
      (match, token) => values[token] ?? match
    );
  }

  @action
  validate(data, { addError, removeError }) {
    if (data.path_format !== "custom") {
      removeError("custom_path_format");
      return;
    }
    const template = data.custom_path_format || "";
    const tokens = [...template.matchAll(PATH_TOKEN)].map((match) => match[1]);
    const valid =
      template.startsWith("/") &&
      tokens.every((token) => PATH_TOKENS.includes(token)) &&
      (tokens.includes("slug") || tokens.includes("id"));
    if (valid) {
      removeError("custom_path_format");
    } else {
      addError("custom_path_format", {
        title: i18n("blog.admin.custom_path_format"),
        message: i18n("blog.admin.custom_path_format_invalid"),
      });
    }
  }

  @action
  async save(data) {
    const { path_format, custom_path_format, ...values } = data;
    values.path_format =
      path_format === "custom" ? custom_path_format : PATH_PRESETS[path_format];
    if (this.args.blog.is_default) {
      delete values.slug;
    }
    this.saving = true;
    try {
      const blog = await ajax(
        `/admin/plugins/blog/blogs/${this.args.blog.id}.json`,
        {
          type: "PUT",
          data: { blog: values },
        }
      );
      storeSiteBlog(this.site, blog);
      this.toasts.success({ data: { message: i18n("blog.admin.saved") } });
      await this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
      throw error;
    } finally {
      this.saving = false;
    }
  }

  <template>
    <Form
      class="blog-settings"
      ...attributes
      @commitOnSubmit={{false}}
      @data={{this.formData}}
      @onSubmit={{this.save}}
      @validate={{this.validate}}
      as |form data|
    >
      <AdminConfigAreaCard @heading="blog.admin.general_heading">
        <:content>
          <form.Section>
            {{#unless @blog.is_default}}
              <form.Field
                @description={{i18n
                  (if
                    @blog.slug_locked
                    "blog.admin.blog_slug_locked"
                    "blog.admin.blog_slug_description"
                  )
                }}
                @disabled={{@blog.slug_locked}}
                @format="full"
                @name="slug"
                @title={{i18n "blog.admin.blog_slug"}}
                @type="input"
                @validation="required"
                as |field|
              ><field.Control /></form.Field>
            {{/unless}}
            {{#if this.showsOwnDomain}}
              <form.Field
                @description={{i18n "blog.admin.blog_url_description"}}
                @format="full"
                @name="url"
                @title={{i18n "blog.admin.blog_url"}}
                @type="input"
                as |field|
              ><field.Control
                  placeholder="https://blog.example.com"
                /></form.Field>
            {{/if}}
            <form.Field
              @description={{i18n
                (if
                  @blog.category_locked
                  "blog.admin.blog_category_locked"
                  "blog.admin.blog_category_description"
                )
              }}
              @format="full"
              @name="category_id"
              @title={{i18n "blog.admin.blog_category"}}
              @type="custom"
              as |field|
            >
              <field.Control>
                <CategoryChooser
                  class="blog-settings__category"
                  @onChange={{field.set}}
                  @options={{hash disabled=@blog.category_locked}}
                  @value={{field.value}}
                />
              </field.Control>
            </form.Field>
            <form.Field
              @format="medium"
              @name="posts_per_page"
              @title={{i18n "blog.admin.posts_per_page"}}
              @type="input-number"
              @validation="required|between:1,30"
              as |field|
            ><field.Control /></form.Field>
          </form.Section>
        </:content>
      </AdminConfigAreaCard>
      <AdminConfigAreaCard @heading="blog.admin.article_urls">
        <:content>
          <form.Section>
            <div class="blog-settings__path-formats --radio-cards">
              <form.Field
                @description={{i18n "blog.admin.path_format_description"}}
                @format="full"
                @name="path_format"
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
                        <span class="blog-settings__path-example"><span
                            class="blog-settings__path-base"
                          >{{this.blogBase}}</span>{{format.example}}</span>
                      </radio.Description>
                    </radioGroup.Radio>
                  {{/each}}
                  <radioGroup.Radio @value="custom" as |radio|>
                    <radio.Title>{{i18n
                        "blog.admin.path_formats.custom"
                      }}</radio.Title>
                    <radio.Description>
                      <span class="blog-settings__path-example"><span
                          class="blog-settings__path-base"
                        >{{this.blogBase}}</span>{{this.pathExample
                          data.custom_path_format
                        }}</span>
                    </radio.Description>
                  </radioGroup.Radio>
                </field.Control>
              </form.Field>
            </div>
            {{#if (eq data.path_format "custom")}}
              <form.Field
                @description={{i18n
                  "blog.admin.custom_path_format_description"
                }}
                @format="full"
                @name="custom_path_format"
                @title={{i18n "blog.admin.custom_path_format"}}
                @type="input"
                @validation="required"
                as |field|
              ><field.Control
                  placeholder="/{year}/{slug}"
                  @before={{this.blogBase}}
                /></form.Field>
            {{/if}}
          </form.Section>
        </:content>
      </AdminConfigAreaCard>
      <form.Actions><form.Submit
          @disabled={{this.saving}}
          @label="blog.admin.save"
        /></form.Actions>
    </Form>
  </template>
}
