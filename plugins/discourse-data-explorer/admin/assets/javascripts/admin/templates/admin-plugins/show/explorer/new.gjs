import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import icon from "discourse/helpers/d-icon";
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
        @title={{i18n "explorer.query_name"}}
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

    {{#if @controller.aiQueriesEnabled}}
      <div class="query-new__or-divider">
        <span>{{i18n "explorer.ai.or_divider"}}</span>
      </div>

      <Form
        @data={{@controller.aiFormData}}
        @onSubmit={{@controller.createWithAi}}
        class="query-new query-new--ai"
        as |form|
      >
        <label class="form-kit__label query-new__ai-label">
          <span>{{i18n "explorer.ai.description_title"}}</span>
          {{icon "discourse-sparkles"}}
        </label>
        <form.Field
          @name="ai_description"
          @title={{i18n "explorer.ai.description_title"}}
          @description={{i18n "explorer.ai.description_hint"}}
          @showTitle={{false}}
          @validation="required"
          @format="large"
          @type="textarea"
          as |field|
        >
          <field.Control
            placeholder={{i18n "explorer.ai.description_placeholder"}}
          />
        </form.Field>
        <form.Actions>
          <form.Submit @label="explorer.ai.generate" />
        </form.Actions>
      </Form>
    {{/if}}
  </div>
</template>
