import Component from "@glimmer/component";
import Form from "discourse/components/form";
import { i18n } from "discourse-i18n";

export default class DsaModerationDetails extends Component {
  formData = {};

  <template>
    <Form
      class="dsa-moderation-details"
      id={{@formId}}
      ...attributes
      @data={{this.formData}}
      @onSubmit={{@onSubmit}}
      as |form|
    >
      <form.Field
        @format="full"
        @name="community_rule"
        @title={{i18n "dsa_statements.rule"}}
        @type="select"
        @validation="required"
        as |field|
      >
        <field.Control
          @nonePlaceholder={{i18n "dsa_statements.rule_prompt"}}
          as |select|
        >
          {{#each @options.community_rules as |rule|}}
            <select.Option @value={{rule.id}}>{{rule.ground}}</select.Option>
          {{/each}}
        </field.Control>
      </form.Field>
      <form.Field
        @format="full"
        @name="category"
        @title={{i18n "dsa_statements.category"}}
        @type="select"
        @validation="required"
        as |field|
      >
        <field.Control
          @nonePlaceholder={{i18n "dsa_statements.category_prompt"}}
          as |select|
        >
          {{#each @options.categories as |category|}}
            <select.Option
              @value={{category.id}}
            >{{category.name}}</select.Option>
          {{/each}}
        </field.Control>
      </form.Field>
    </Form>
  </template>
}
