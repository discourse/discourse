import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { slugify } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import { storeSiteBlog } from "discourse/plugins/blog/discourse/lib/site-blogs";

const FIELDS = {
  name: "blog.admin.blog_title",
  slug: "blog.admin.blog_slug",
};

export default class BlogNewForm extends Component {
  @service router;
  @service site;

  @tracked saving = false;

  #formApi;
  #slugEdited = false;

  @action
  registerApi(api) {
    this.#formApi = api;
  }

  @action
  setName(value, { set }) {
    set("name", value);
    if (!this.#slugEdited) {
      set("slug", slugify(value));
    }
  }

  @action
  setSlug(value, { set }) {
    this.#slugEdited = value !== "";
    set("slug", value);
  }

  @action
  async create(data) {
    this.saving = true;
    try {
      const blog = await ajax("/admin/plugins/blog/blogs.json", {
        type: "POST",
        data: { blog: data },
      });
      storeSiteBlog(this.site, blog);
      this.router.transitionTo(
        "adminPlugins.show.discourse-blog-blogs.edit.about",
        blog.id
      );
    } catch (error) {
      if (!this.#showFieldErrors(error)) {
        popupAjaxError(error);
      }
    } finally {
      this.saving = false;
    }
  }

  #showFieldErrors(error) {
    const errors = error.jqXHR?.responseJSON?.extras?.field_errors;
    const names = Object.keys(errors || {});
    if (!names.length || names.some((name) => !FIELDS[name])) {
      return false;
    }
    names.forEach((name) =>
      errors[name].forEach((message) =>
        this.#formApi.addError(name, { title: i18n(FIELDS[name]), message })
      )
    );
    return true;
  }

  <template>
    <Form
      class="blog-new-form"
      @onRegisterApi={{this.registerApi}}
      @onSubmit={{this.create}}
      as |form|
    >
      <AdminConfigAreaCard
        @description="blog.admin.new_blog_description"
        @heading="blog.admin.new_blog"
      >
        <:content>
          <form.Section>
            <form.Field
              @format="max"
              @name="name"
              @onSet={{this.setName}}
              @title={{i18n "blog.admin.blog_title"}}
              @type="input"
              @validation="required"
              as |field|
            ><field.Control /></form.Field>
            <form.Field
              @description={{i18n "blog.admin.blog_slug_description"}}
              @format="max"
              @name="slug"
              @onSet={{this.setSlug}}
              @title={{i18n "blog.admin.blog_slug"}}
              @type="input"
              @validation="required"
              as |field|
            ><field.Control placeholder="engineering" /></form.Field>
          </form.Section>
        </:content>
      </AdminConfigAreaCard>
      <form.Actions><form.Submit
          @disabled={{this.saving}}
          @label="blog.admin.create_blog"
        /></form.Actions>
    </Form>
  </template>
}
