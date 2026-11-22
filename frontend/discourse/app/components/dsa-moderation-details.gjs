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
  return {
    ...(rules?.length === 1 && { community_rule: rules[0].id }),
    ...(options?.default_category && { category: options.default_category }),
  };
}

function selectionLabel(options, value, labelKey, placeholder) {
  return (
    options.find((option) => option.id === value)?.[labelKey] ?? placeholder
  );
}

export default class DsaModerationDetails extends Component {
  formData = defaultClassification(this.args.options);

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
        @tooltip={{i18n "dsa_statements.rule_help"}}
        @type="menu"
        @validation="required"
        as |field|
      >
        <field.Control
          @selection={{selectionLabel
            @options.community_rules
            field.value
            "ground"
            (i18n "dsa_statements.rule_prompt")
          }}
          as |menu|
        >
          {{#each @options.community_rules key="id" as |rule|}}
            <menu.Item
              class={{if rule.explanation "--with-description"}}
              @value={{rule.id}}
            >
              {{#if rule.explanation}}
                <span>
                  <strong>{{rule.ground}}</strong><br />
                  <small>{{rule.explanation}}</small>
                </span>
              {{else}}
                {{rule.ground}}
              {{/if}}
            </menu.Item>
          {{/each}}
        </field.Control>
      </form.Field>
      <form.Field
        @disabled={{@disabled}}
        @format="full"
        @helpText={{@fieldHints.category}}
        @name="category"
        @onSet={{@onFieldSet}}
        @title={{i18n "dsa_statements.category"}}
        @tooltip={{component CategoryHelp}}
        @type="menu"
        @validation="required"
        as |field|
      >
        <field.Control
          @selection={{selectionLabel
            @options.categories
            field.value
            "name"
            (i18n "dsa_statements.category_prompt")
          }}
          as |menu|
        >
          {{#each @options.categories key="id" as |category|}}
            <menu.Item @value={{category.id}}>{{category.name}}</menu.Item>
          {{/each}}
        </field.Control>
      </form.Field>
    </Form>
  </template>
}
