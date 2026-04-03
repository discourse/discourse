import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-detail">
    <BackButton
      @route="adminPlugins.show.explorer.index"
      @label="explorer.queries"
    />

    <Form
      @data={{@controller.model}}
      @onSubmit={{@controller.create}}
      class="query-new"
      as |form|
    >
      <form.Field
        @name="name"
        @title={{i18n "explorer.create_placeholder"}}
        @validation="required"
        @format="large"
        @type="input"
        as |field|
      >
        <field.Control />
      </form.Field>
      <form.Field
        @name="description"
        @title={{i18n "explorer.description_placeholder"}}
        @format="large"
        @type="textarea"
        as |field|
      >
        <field.Control />
      </form.Field>
      <form.Actions>
        <form.Submit @label="explorer.create" @icon="plus" />
      </form.Actions>
    </Form>
  </div>
</template>
