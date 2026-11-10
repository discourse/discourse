import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import DsaClassificationSelect from "discourse/components/dsa-classification-select";
import Form from "discourse/components/form";
import PluginOutlet from "discourse/components/plugin-outlet";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import lazyHash from "discourse/helpers/lazy-hash";
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
      @onSubmit={{@onSubmit}}
      as |form|
    >
      <form.Field
        @format="full"
        @name="community_rule"
        @title={{i18n "dsa_statements.rule"}}
        @tooltip={{i18n "dsa_statements.rule_help"}}
        @type="custom"
        @validation="required"
        as |field|
      >
        <field.Control>
          <PluginOutlet
            @name="dsa-community-rule-control"
            @outletArgs={{lazyHash
              field=field
              options=this.rules
              placeholder=(i18n "dsa_statements.rule_prompt")
              reviewableId=@reviewableId
            }}
          >
            <DsaClassificationSelect
              @field={{field}}
              @options={{this.rules}}
              @placeholder={{i18n "dsa_statements.rule_prompt"}}
            />
          </PluginOutlet>
        </field.Control>
      </form.Field>
      <form.Field
        @format="full"
        @name="category"
        @title={{i18n "dsa_statements.category"}}
        @tooltip={{component CategoryHelp}}
        @type="custom"
        @validation="required"
        as |field|
      >
        <field.Control>
          <PluginOutlet
            @name="dsa-category-control"
            @outletArgs={{lazyHash
              field=field
              options=@options.categories
              placeholder=(i18n "dsa_statements.category_prompt")
              reviewableId=@reviewableId
            }}
          >
            <DsaClassificationSelect
              @field={{field}}
              @options={{@options.categories}}
              @placeholder={{i18n "dsa_statements.category_prompt"}}
            />
          </PluginOutlet>
        </field.Control>
      </form.Field>
    </Form>
  </template>
}
