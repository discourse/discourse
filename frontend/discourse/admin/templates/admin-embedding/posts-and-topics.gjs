import { hash } from "@ember/helper";
import Form from "discourse/components/form";
import legacyPickOne from "discourse/lib/legacy-pick-one";
import UserChooser from "discourse/select-kit/components/user-chooser";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageSubheader @titleLabel={{i18n "admin.embedding.posts_and_topics"}} />

  <Form @data={{@controller.formData}} @onSubmit={{@controller.save}} as |form|>
    <form.Field
      @name="embed_by_username"
      @title={{i18n "admin.embedding.embed_by_username"}}
      @type="custom"
      @validation="required"
      as |field|
    >
      <field.Control>
        {{! TODO (select-kit-replacement-cleanup) }}
        {{#if @controller.siteSettings.enable_new_select_controls}}
          <DSelectUser
            class="admin-embedding-posts-and-topics-form__embed_by_username"
            @describedBy={{field.describedBy}}
            @disabled={{field.disabled}}
            @id={{field.id}}
            @invalid={{if field.error true false}}
            @onChange={{legacyPickOne field.set}}
            @texts={{hash ariaLabel=field.title}}
            @value={{field.value}}
          />
        {{else}}
          {{! TODO (select-kit-replacement-cleanup) }}
          <UserChooser
            class="admin-embedding-posts-and-topics-form__embed_by_username"
            @onChange={{field.set}}
            @options={{hash maximum=1 excludeCurrentUser=false}}
            @value={{field.value}}
          />
        {{/if}}
      </field.Control>
    </form.Field>
    <form.Field
      @format="large"
      @name="embed_post_limit"
      @title={{i18n "admin.embedding.embed_post_limit"}}
      @type="input"
      as |field|
    >
      <field.Control />
    </form.Field>
    <form.Field
      @format="large"
      @name="embed_title_scrubber"
      @title={{i18n "admin.embedding.embed_title_scrubber"}}
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
