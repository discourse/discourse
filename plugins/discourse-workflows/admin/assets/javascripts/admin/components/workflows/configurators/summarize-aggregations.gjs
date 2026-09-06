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
      @form={{@form}}
      @formApi={{@formApi}}
      @configuration={{@configuration}}
      @connections={{@connections}}
      @credentials={{@credentials}}
      @fieldName={{@fieldName}}
      @showLabel={{false}}
      @node={{@node}}
      @nodeDefinition={{@nodeDefinition}}
      @nodeParameters={{@nodeParameters}}
      @nodes={{@nodes}}
      @nodeType={{@nodeType}}
      @nodeTypes={{@nodeTypes}}
      @schema={{@schema}}
      @session={{@session}}
      as |row|
    >
      <div class="workflows-summarize-row">
        <div class="workflows-summarize-row__line">
          <row.object.Field
            @name="aggregation"
            @title={{this.fieldTitle "aggregation"}}
            @showTitle={{false}}
            class="workflows-summarize-row__lead"
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
              @name="field"
              @title={{this.fieldTitle "field"}}
              @showTitle={{false}}
              class="workflows-summarize-row__control"
              as |field|
            >
              <FieldPathControl
                @field={{field}}
                @schema={{this.fieldSchema "field"}}
                @node={{@node}}
                @nodes={{@nodes}}
                @nodeTypes={{@nodeTypes}}
                @connections={{@connections}}
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
              @name="separate_by"
              @title={{this.fieldTitle "separate_by"}}
              @showTitle={{false}}
              class="workflows-summarize-row__control"
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
              @name="custom_separator"
              @title={{this.fieldTitle "custom_separator"}}
              @showTitle={{false}}
              class="workflows-summarize-row__control"
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
            @name="output_field_name"
            @title={{this.fieldTitle "output_field_name"}}
            @showTitle={{false}}
            @placeholder={{derivedPlaceholder row.item}}
            class="workflows-summarize-row__control
              {{if
                (isDerived row.item)
                'workflows-summarize-row__control--derived'
              }}"
            as |field|
          >
            <field.Input />
          </row.object.Field>
        </div>
      </div>
    </FixedCollection>
  </template>
}
