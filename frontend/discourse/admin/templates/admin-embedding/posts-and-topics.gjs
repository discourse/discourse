import { hash } from "@ember/helper";
import Form from "discourse/components/form";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageSubheader @titleLabel={{i18n "admin.embedding.posts_and_topics"}} />

  <Form @onSubmit={{@controller.save}} @data={{@controller.formData}} as |form|>
    <form.Field
      @name="embed_by_username"
      @title={{i18n "admin.embedding.embed_by_username"}}
      @validation="required"
      @type="custom"
      as |field|
    >
      <field.Control>
        <UserChooser
          @value={{field.value}}
          @onChange={{field.set}}
          @options={{hash maximum=1 excludeCurrentUser=false}}
          class="admin-embedding-posts-and-topics-form__embed_by_username"
        />
      </field.Control>
    </form.Field>
    <form.Field
      @name="embed_post_limit"
      @title={{i18n "admin.embedding.embed_post_limit"}}
      @format="large"
      @type="input"
      as |field|
    >
      <field.Control />
    </form.Field>
    <form.Field
      @name="embed_title_scrubber"
      @title={{i18n "admin.embedding.embed_title_scrubber"}}
      @format="large"
      @type="input"
      as |field|
    >
      <field.Control placeholder="- site.com$" />
    </form.Field>
    <form.CheckboxGroup as |checkboxGroup|>
      <checkboxGroup.Field
        @name="embed_truncate"
        @title={{i18n "admin.embedding.embed_truncate"}}
        @type="checkbox"
        as |field|
      >
        <field.Control />
      </checkboxGroup.Field>

      <checkboxGroup.Field
        @name="embed_unlisted"
        @title={{i18n "admin.embedding.embed_unlisted"}}
        @type="checkbox"
        as |field|
      >
        <field.Control />
      </checkboxGroup.Field>
    </form.CheckboxGroup>
    <form.Submit @label="admin.embedding.save" />
  </Form>
</template>
