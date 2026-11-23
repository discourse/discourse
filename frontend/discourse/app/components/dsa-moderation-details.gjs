import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import DsaClassificationSelect from "discourse/components/dsa-classification-select";
import Form from "discourse/components/form";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { i18n } from "discourse-i18n";

function preventFieldActivation(event) {
  event.preventDefault();
}

const ClassificationHelp = <template>
  <DTooltip
    class="form-kit__tooltip"
    @icon="circle-question"
    @interactive={{@interactive}}
    {{on "click" preventFieldActivation}}
  >
    <:content>
      <div>{{trustHTML @content}}</div>
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
        @helpText={{@fieldHints.community_rule}}
        @name="community_rule"
        @onSet={{@onFieldSet}}
        @title={{i18n "dsa_statements.rule"}}
        @tooltip={{component
          ClassificationHelp
          content=(i18n "dsa_statements.rule_help")
        }}
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
        @helpText={{@fieldHints.category}}
        @name="category"
        @onSet={{@onFieldSet}}
        @title={{i18n "dsa_statements.category"}}
        @tooltip={{component
          ClassificationHelp
          content=(i18n "dsa_statements.category_help")
          interactive=true
        }}
        @type="custom"
        @validation="required"
        as |field|
      >
        <field.Control>
          <DsaClassificationSelect
            @field={{field}}
            @options={{@options.categories}}
            @placeholder={{i18n "dsa_statements.category_prompt"}}
          />
        </field.Control>
      </form.Field>
    </Form>
  </template>
}
