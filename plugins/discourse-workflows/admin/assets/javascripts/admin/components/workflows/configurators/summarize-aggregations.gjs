import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import {
  fieldVisible,
  normalizeOptions,
  normalizeSchema,
  propertyLabel,
  propertyOptionLabel,
} from "../../../lib/workflows/property-engine";
import {
  summarizeOutputKey,
  summarizeOutputKeyIsDerived,
} from "../../../lib/workflows/summarize-output-key";
import FieldPathControl from "./field-path-control";
import FixedCollection from "./fixed-collection";

function isVisible(field, item) {
  return field ? fieldVisible(field, item) : false;
}

function isDerived(item) {
  return summarizeOutputKeyIsDerived(item || {});
}

function derivedPlaceholder(item) {
  return summarizeOutputKeyIsDerived(item || {})
    ? summarizeOutputKey(item || {})
    : "";
}

export default class SummarizeAggregations extends Component {
  fieldSchema = (name) => {
    return this.rowFields.find((field) => field.name === name);
  };

  fieldTitle = (name) => {
    return propertyLabel(this.args.nodeDefinition, name);
  };

  get rowFields() {
    const group = (this.args.schema?.options || [])[0] || { values: {} };
    return normalizeSchema(group.values || {});
  }

  get aggregationOptions() {
    const schema = this.fieldSchema("aggregation");

    return normalizeOptions(schema?.options || []).map((option) => ({
      ...option,
      label: propertyOptionLabel(
        this.args.nodeDefinition,
        "aggregation",
        option
      ),
    }));
  }

  get separatorOptions() {
    const schema = this.fieldSchema("separate_by");

    return normalizeOptions(schema?.options || []).map((option) => ({
      ...option,
      label: propertyOptionLabel(
        this.args.nodeDefinition,
        "separate_by",
        option
      ),
    }));
  }

  <template>
    <FixedCollection
      @configuration={{@configuration}}
      @connections={{@connections}}
      @credentials={{@credentials}}
      @fieldName={{@fieldName}}
      @form={{@form}}
      @formApi={{@formApi}}
      @node={{@node}}
      @nodeDefinition={{@nodeDefinition}}
      @nodeParameters={{@nodeParameters}}
      @nodes={{@nodes}}
      @nodeType={{@nodeType}}
      @nodeTypes={{@nodeTypes}}
      @schema={{@schema}}
      @session={{@session}}
      @showLabel={{false}}
      as |row|
    >
      <div class="workflows-summarize-row">
        <div class="workflows-summarize-row__line">
          <row.object.Field
            class="workflows-summarize-row__lead"
            @name="aggregation"
            @showTitle={{false}}
            @title={{this.fieldTitle "aggregation"}}
            as |field|
          >
            <field.Select @includeNone={{false}} as |select|>
              {{#each this.aggregationOptions key="value" as |choice|}}
                <select.Option @value={{choice.value}}>
                  {{choice.label}}
                </select.Option>
              {{/each}}
            </field.Select>
          </row.object.Field>

          {{#if (isVisible (this.fieldSchema "field") row.item)}}
            <row.object.Field
              class="workflows-summarize-row__control"
              @name="field"
              @showTitle={{false}}
              @title={{this.fieldTitle "field"}}
              as |field|
            >
              <FieldPathControl
                @connections={{@connections}}
                @field={{field}}
                @node={{@node}}
                @nodes={{@nodes}}
                @nodeTypes={{@nodeTypes}}
                @schema={{this.fieldSchema "field"}}
                @session={{@session}}
              />
            </row.object.Field>
          {{/if}}
        </div>

        {{#if (isVisible (this.fieldSchema "separate_by") row.item)}}
          <div class="workflows-summarize-row__line">
            <span
              class="workflows-summarize-row__lead workflows-summarize-row__lead--label"
            >
              {{this.fieldTitle "separate_by"}}
            </span>

            <row.object.Field
              class="workflows-summarize-row__control"
              @name="separate_by"
              @showTitle={{false}}
              @title={{this.fieldTitle "separate_by"}}
              as |field|
            >
              <field.Select @includeNone={{false}} as |select|>
                {{#each this.separatorOptions key="value" as |choice|}}
                  <select.Option @value={{choice.value}}>
                    {{choice.label}}
                  </select.Option>
                {{/each}}
              </field.Select>
            </row.object.Field>
          </div>
        {{/if}}

        {{#if (isVisible (this.fieldSchema "custom_separator") row.item)}}
          <div class="workflows-summarize-row__line">
            <span
              class="workflows-summarize-row__lead workflows-summarize-row__lead--label"
            >
              {{this.fieldTitle "custom_separator"}}
            </span>

            <row.object.Field
              class="workflows-summarize-row__control"
              @name="custom_separator"
              @showTitle={{false}}
              @title={{this.fieldTitle "custom_separator"}}
              as |field|
            >
              <field.Input />
            </row.object.Field>
          </div>
        {{/if}}

        <div class="workflows-summarize-row__line">
          <span
            class="workflows-summarize-row__lead workflows-summarize-row__lead--label"
          >
            {{i18n "discourse_workflows.summarize.as"}}
          </span>

          <row.object.Field
            class="workflows-summarize-row__control
              {{if
                (isDerived row.item)
                'workflows-summarize-row__control--derived'
              }}"
            @name="output_field_name"
            @placeholder={{derivedPlaceholder row.item}}
            @showTitle={{false}}
            @title={{this.fieldTitle "output_field_name"}}
            as |field|
          >
            <field.Input />
          </row.object.Field>
        </div>
      </div>
    </FixedCollection>
  </template>
}
