import { hash } from "@ember/helper";
import DPageSubheader from "discourse/components/d-page-subheader";
import Form from "discourse/components/form";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageSubheader @titleLabel={{i18n "admin.embedding.posts_and_topics"}} />

  <Form @onSubmit={{@controller.save}} @data={{@controller.formData}} as |form|>
    <form.Field
      @name="embed_by_username"
      @title={{i18n "admin.embedding.embed_by_username"}}
      @validation="required"
      @type="custom"
      as |Control field|
    >
      <Control>
        <UserChooser
          @value={{field.value}}
          @onChange={{field.set}}
          @options={{hash maximum=1 excludeCurrentUser=false}}
          class="admin-embedding-posts-and-topics-form__embed_by_username"
        />
      </Control>
    </form.Field>
    <form.Field
      @name="embed_post_limit"
      @title={{i18n "admin.embedding.embed_post_limit"}}
      @format="large"
      @type="input-text"
      as |Control|
    >
      <Control />
    </form.Field>
    <form.Field
      @name="embed_title_scrubber"
      @title={{i18n "admin.embedding.embed_title_scrubber"}}
      @format="large"
      @type="input-text"
      as |Control|
    >
      <Control placeholder="- site.com$" />
    </form.Field>
    <form.CheckboxGroup as |checkboxGroup|>
      <checkboxGroup.Field
        @name="embed_truncate"
        @title={{i18n "admin.embedding.embed_truncate"}}
        @type="checkbox"
        as |Control|
      >
        <Control />
      </checkboxGroup.Field>

      <checkboxGroup.Field
        @name="embed_unlisted"
        @title={{i18n "admin.embedding.embed_unlisted"}}
        @type="checkbox"
        as |Control|
      >
        <Control />
      </checkboxGroup.Field>
    </form.CheckboxGroup>
    <form.Submit @label="admin.embedding.save" />
  </Form>
</template>
