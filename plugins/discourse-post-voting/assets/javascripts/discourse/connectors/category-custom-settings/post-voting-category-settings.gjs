import { i18n } from "discourse-i18n";

export default <template>
  <@outletArgs.form.Section
    @title={{i18n "category.post_voting_settings_heading"}}
    class="category-custom-settings-outlet post-voting-category-settings"
  >
    <@outletArgs.form.Object @name="custom_fields" as |object|>
      <object.Field
        @name="create_as_post_voting_default"
        @title={{i18n "category.create_as_post_voting_default"}}
        @format="max"
        @type="checkbox"
        as |field|
      >
        <field.Control />
      </object.Field>

      <object.Field
        @name="only_post_voting_in_this_category"
        @title={{i18n "category.only_post_voting_in_this_category"}}
        @format="max"
        @type="checkbox"
        as |field|
      >
        <field.Control />
      </object.Field>
    </@outletArgs.form.Object>
  </@outletArgs.form.Section>
</template>
