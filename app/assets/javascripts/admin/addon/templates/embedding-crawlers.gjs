import RouteTemplate from "ember-route-template";
import DPageSubheader from "discourse/components/d-page-subheader";
import Form from "discourse/components/form";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <DPageSubheader
      @titleLabel={{i18n "admin.embedding.crawlers"}}
      @descriptionLabel={{i18n "admin.embedding.crawlers_description"}}
    />

    <Form
      @onSubmit={{@controller.save}}
      @data={{@controller.formData}}
      as |form|
    >
      <form.Field
        @name="allowed_embed_selectors"
        @title={{i18n "admin.embedding.allowed_embed_selectors"}}
        @format="large"
        as |field|
      >
        <field.Input placeholder="article, #story, .post" />
      </form.Field>
      <form.Field
        @name="blocked_embed_selectors"
        @title={{i18n "admin.embedding.blocked_embed_selectors"}}
        @format="large"
        as |field|
      >
        <field.Input placeholder=".ad-unit, header" />
      </form.Field>
      <form.Field
        @name="allowed_embed_classnames"
        @title={{i18n "admin.embedding.allowed_embed_classnames"}}
        @format="large"
        as |field|
      >
        <field.Input placeholder="emoji, classname" />
      </form.Field>
      <form.Submit @label="admin.embedding.save" />
    </Form>
  </template>
);
