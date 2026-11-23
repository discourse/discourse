import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

function preventFieldActivation(event) {
  event.preventDefault();
}

const ClassificationHelp = <template>
  {{#if @selectedLabel}}
    <span class="dsa-classification-selected-label sr-only">
      {{@selectedLabel}}
    </span>
  {{/if}}
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

const ClassificationMenuOption = <template>
  {{#let (eq @option.id @value) as |selected|}}
    <@Item
      aria-current={{if selected "true"}}
      class={{dConcatClass
        "dsa-classification-option"
        (if @option.description "--with-description")
      }}
      @value={{@option.id}}
    >
      {{#if @option.description}}
        <span>
          <strong>{{@option.name}}</strong><br />
          <small>{{@option.description}}</small>
        </span>
      {{else}}
        {{@option.name}}
      {{/if}}
      {{#if selected}}
        <span class="d-button__suffix-icon">{{dIcon "check"}}</span>
      {{/if}}
    </@Item>
  {{/let}}
</template>;

function selectionLabel(options, value, placeholder) {
  return options.find((option) => option.id === value)?.name ?? placeholder;
}

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
      as |form data|
    >
      {{! TODO (select-kit-replacement-cleanup) }}
      {{#if this.siteSettings.enable_new_select_controls}}
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
          </field.Control>
        </form.Field>
      {{else}}
        {{! TODO (select-kit-replacement-cleanup) }}
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
            selectedLabel=(selectionLabel this.rules data.community_rule)
          }}
          @type="menu"
          @validation="required"
          as |field|
        >
          <field.Control
            @selection={{selectionLabel
              this.rules
              field.value
              (i18n "dsa_statements.rule_prompt")
            }}
            as |menu|
          >
            {{#each this.rules key="id" as |rule|}}
              <ClassificationMenuOption
                @Item={{menu.Item}}
                @option={{rule}}
                @value={{field.value}}
              />
            {{/each}}
          </field.Control>
        </form.Field>
      {{/if}}
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
          selectedLabel=(selectionLabel @options.categories data.category)
        }}
        @type="menu"
        @validation="required"
        as |field|
      >
        <field.Control
          @selection={{selectionLabel
            @options.categories
            field.value
            (i18n "dsa_statements.category_prompt")
          }}
          as |menu|
        >
          {{#each @options.categories key="id" as |category|}}
            <ClassificationMenuOption
              @Item={{menu.Item}}
              @option={{category}}
              @value={{field.value}}
            />
          {{/each}}
        </field.Control>
      </form.Field>
    </Form>
  </template>
}
