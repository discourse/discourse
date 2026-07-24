import Form from "discourse/components/form";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageSubheader
    @titleLabel={{i18n "admin.embedding.crawlers"}}
    @descriptionLabel={{i18n "admin.embedding.crawlers_description"}}
  />

  <Form @onSubmit={{@controller.save}} @data={{@controller.formData}} as |form|>
    <form.Field
      @name="allowed_embed_selectors"
      @title={{i18n "admin.embedding.allowed_embed_selectors"}}
      @format="large"
      @type="input"
      as |field|
    >
      <field.Control placeholder="article, #story, .post" />
    </form.Field>
    <form.Field
      @name="blocked_embed_selectors"
      @title={{i18n "admin.embedding.blocked_embed_selectors"}}
      @format="large"
      @type="input"
      as |field|
    >
      <field.Control placeholder=".ad-unit, header" />
    </form.Field>
    <form.Field
      @name="allowed_embed_classnames"
      @title={{i18n "admin.embedding.allowed_embed_classnames"}}
      @format="large"
      @type="input"
      as |field|
    >
      <field.Control placeholder="emoji, classname" />
    </form.Field>
    <form.Submit @label="admin.embedding.save" />
  </Form>
</template>
