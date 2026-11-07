import Component from "@glimmer/component";
import { array, fn } from "@ember/helper";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import DMenu from "discourse/float-kit/components/d-menu";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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

function ruleName(rules, ruleId) {
  return (
    rules.find((rule) => rule.id === ruleId)?.ground ||
    i18n("dsa_statements.rule_prompt")
  );
}

function selectRule(field, close, ruleId) {
  field.set(ruleId);
  return close({ focusTrigger: true });
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
      as |form data|
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
          <DMenu
            aria-describedby={{field.describedBy}}
            aria-description={{ruleName
              @options.community_rules
              data.community_rule
            }}
            aria-invalid={{if field.error "true"}}
            id={{field.id}}
            @contentClass="form-kit__control-menu-content dsa-community-rules"
            @disabled={{field.disabled}}
            @fallbackPlacements={{array "top-start"}}
            @label={{ruleName @options.community_rules data.community_rule}}
            @matchTriggerWidth={{true}}
            @modalForMobile={{true}}
            @placement="bottom-start"
            @triggerClass="form-kit__control-menu-trigger dsa-community-rule-trigger"
          >
            <:trigger>{{dIcon "angle-down"}}</:trigger>
            <:content as |menu|>
              <DDropdownMenu as |dropdown|>
                {{#each @options.community_rules as |rule|}}
                  <dropdown.item>
                    <DButton
                      class="btn-flat dsa-community-rule --with-description"
                      @action={{fn selectRule field menu.close rule.id}}
                    >
                      <span class="dsa-community-rule__texts">
                        <span class="dsa-community-rule__name">
                          {{rule.ground}}
                        </span>
                        <span class="dsa-community-rule__explanation">
                          {{rule.explanation}}
                        </span>
                      </span>
                    </DButton>
                  </dropdown.item>
                {{/each}}
              </DDropdownMenu>
            </:content>
          </DMenu>
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
