import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { storeSiteBlog } from "discourse/plugins/blog/discourse/lib/site-blogs";

export default class BlogAbout extends Component {
  @service router;
  @service site;
  @service toasts;

  @tracked saving = false;

  get formData() {
    const { name, description, about } = this.args.blog;
    return { name, description: description || "", about: about || "" };
  }

  @action
  async save(data) {
    this.saving = true;
    try {
      const blog = await ajax(
        `/admin/plugins/blog/blogs/${this.args.blog.id}.json`,
        {
          type: "PUT",
          data: { blog: data },
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
    <div class="blog-about" ...attributes>
      <Form
        class="blog-about__form"
        @commitOnSubmit={{false}}
        @data={{this.formData}}
        @onSubmit={{this.save}}
        as |form|
      >
        <form.Section>
          <form.Field
            @format="full"
            @name="name"
            @title={{i18n "blog.admin.blog_title"}}
            @type="input"
            @validation="required"
            as |field|
          ><field.Control /></form.Field>
          <form.Field
            @format="full"
            @name="description"
            @title={{i18n "blog.admin.tagline"}}
            @type="textarea"
            as |field|
          ><field.Control @rows={{2}} /></form.Field>
          <form.Field
            @format="full"
            @name="about"
            @title={{i18n "blog.admin.about"}}
            @type="composer"
            as |field|
          ><field.Control @height={{220}} /></form.Field>
        </form.Section>
        <form.Actions><form.Submit
            @disabled={{this.saving}}
            @label="blog.admin.save"
          /></form.Actions>
      </Form>
    </div>
  </template>
}
