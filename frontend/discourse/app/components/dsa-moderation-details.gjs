import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import DsaClassificationSelect from "discourse/components/dsa-classification-select";
import Form from "discourse/components/form";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
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
  @service siteSettings;

  formData = defaultClassification(this.args.options);

  get ruleOptions() {
    return this.args.options.community_rules.map((rule) =>
      selectOption(rule, { description: rule.explanation })
    );
  }

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
          {{! TODO (select-kit-replacement-cleanup) }}
          {{#if this.siteSettings.enable_new_select_controls}}
            <DSelect
              @describedBy={{field.describedBy}}
              @disabled={{field.disabled}}
              @id={{field.id}}
              @invalid={{if field.error true false}}
              @labelField="ground"
              @onChange={{field.set}}
              @options={{this.ruleOptions}}
              @texts={{hash
                ariaLabel=field.title
                placeholder=(i18n "dsa_statements.rule_prompt")
              }}
              @value={{field.value}}
            />
          {{else}}
            {{! TODO (select-kit-replacement-cleanup) }}
            <DsaClassificationSelect
              @field={{field}}
              @options={{this.rules}}
              @placeholder={{i18n "dsa_statements.rule_prompt"}}
            />
          {{/if}}
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
