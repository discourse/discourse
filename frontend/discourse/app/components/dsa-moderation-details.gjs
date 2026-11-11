import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import DsaClassificationSelect from "discourse/components/dsa-classification-select";
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
  return {
    ...(rules?.length === 1 && { community_rule: rules[0].id }),
    ...(options?.default_category && { category: options.default_category }),
  };
}

export default class DsaModerationDetails extends Component {
  formData = defaultClassification(this.args.options);

  get rules() {
    return this.args.options.community_rules.map((rule) => ({
      id: rule.id,
      name: rule.ground,
      description: rule.explanation,
    }));
  }

  <template>
    <Form
      class="dsa-moderation-details"
      id={{@formId}}
      ...attributes
      @data={{this.formData}}
      @onRegisterApi={{@onRegisterApi}}
      @onSubmit={{@onSubmit}}
      @validate={{@validate}}
      as |form|
    >
      <form.Field
        @disabled={{@disabled}}
        @format="full"
        @name="community_rule"
        @title={{i18n "dsa_statements.rule"}}
        @tooltip={{i18n "dsa_statements.rule_help"}}
        @type="custom"
        @validation="required"
        as |field|
      >
        <field.Control>
          <DsaClassificationSelect
            @field={{field}}
            @options={{this.rules}}
            @placeholder={{i18n "dsa_statements.rule_prompt"}}
          />
        </field.Control>
      </form.Field>
      <form.Field
        @disabled={{@disabled}}
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
