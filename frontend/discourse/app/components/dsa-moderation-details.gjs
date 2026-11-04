import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { i18n } from "discourse-i18n";

const CategoryHelp = <template>
  <DTooltip
    class="form-kit__tooltip"
    @icon="circle-question"
    @interactive={{true}}
  >
    <:content>
      <div>{{trustHTML (i18n "dsa_statements.category_help")}}</div>
    </:content>
  </DTooltip>
</template>;

export function defaultClassification(options) {
  const rules = options?.community_rules;
  return rules?.length === 1 ? { community_rule: rules[0].id } : {};
}

export default class DsaModerationDetails extends Component {
  formData = defaultClassification(this.args.options);

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
        @tooltip={{i18n "dsa_statements.rule_help"}}
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
        @tooltip={{component CategoryHelp}}
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
