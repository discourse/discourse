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
const PATH_PRESETS = {
  slug: "/{slug}",
  year_month_slug: "/{year}/{month}/{slug}",
  year_month_day_slug: "/{year}/{month}/{day}/{slug}",
};
const PATH_TOKEN = /\{(\w+)\}/g;
const PATH_TOKENS = ["year", "month", "day", "slug", "id"];

export default class BlogIdentity extends Component {
  @service site;
  @service toasts;

  @tracked saving = false;

  get formData() {
    const settings = this.args.settings;
    const format = settings.blog_path_format || PATH_PRESETS.slug;
    const preset = Object.keys(PATH_PRESETS).find(
      (key) => PATH_PRESETS[key] === format
    );
    return {
      ...Object.fromEntries(SETTINGS.map((key) => [key, settings[key] || ""])),
      path_format: preset || "custom",
      custom_path_format: preset ? "" : format,
    };
  }

  get pathFormats() {
    return Object.entries(PATH_PRESETS).map(([value, template]) => ({
      value,
      example: this.pathExample(template),
    }));
  }

  get blogBase() {
    // On the forum's own host the path is enough; a separate blog domain is worth showing.
    const url = new URL(this.site.blog_base_url, window.location.origin);
    const path = url.pathname.replace(/\/$/, "");
    return url.host === window.location.host ? path : `${url.host}${path}`;
  }

  get safeUrl() {
    return `${this.site.blog_base_url}/?blog_safe_mode=1`;
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
    const { path_format, custom_path_format, ...settings } = data;
    settings.blog_path_format =
      path_format === "custom" ? custom_path_format : PATH_PRESETS[path_format];
    this.saving = true;
    try {
      await SiteSetting.bulkUpdate(
        Object.fromEntries(
          Object.entries(settings).map(([key, value]) => [key, { value }])
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
      <Form
        class="blog-identity__form"
        @commitOnSubmit={{false}}
        @data={{this.formData}}
        @onSubmit={{this.save}}
        @validate={{this.validate}}
        as |form data|
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
                          <span class="blog-identity__path-example"><span
                              class="blog-identity__path-base"
                            >{{this.blogBase}}</span>{{format.example}}</span>
                        </radio.Description>
                      </radioGroup.Radio>
                    {{/each}}
                    <radioGroup.Radio @value="custom" as |radio|>
                      <radio.Title>{{i18n
                          "blog.admin.path_formats.custom"
                        }}</radio.Title>
                      <radio.Description>
                        <span class="blog-identity__path-example"><span
                            class="blog-identity__path-base"
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
                  @format="large"
                  @name="custom_path_format"
                  @title={{i18n "blog.admin.custom_path_format"}}
                  @type="input"
                  @validation="required"
                  as |field|
                ><field.Control placeholder="/news/{slug}" /></form.Field>
              {{/if}}
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
