import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import DButton from "discourse/ui-kit/d-button";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import { i18n } from "discourse-i18n";

function isExpression(value) {
  return typeof value === "string" && value.startsWith("=");
}

function isObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function parseJson(value, type) {
  try {
    const parsed = JSON.parse(value);
    if (type === "array" ? Array.isArray(parsed) : isObject(parsed)) {
      return parsed;
    }
  } catch {
    // Keep invalid JSON in the editor without overwriting the saved value.
  }
}

function schemaForArgument(argument) {
  const { type, required, enum: values } = argument;
  const choices = values?.length
    ? values
    : type === "boolean"
      ? [true, false]
      : null;
  return {
    type,
    required,
    ui: { expression: true, control: choices ? "select" : undefined },
    options: choices?.map((value) => ({
      value: String(value),
      label:
        typeof value === "boolean"
          ? i18n(
              value
                ? "discourse_ai.discourse_workflows.ai_tool.true_value"
                : "discourse_ai.discourse_workflows.ai_tool.false_value"
            )
          : String(value),
    })),
    choices,
  };
}

class JsonInput extends Component {
  syncValidity = modifier((element, [invalid]) => {
    element.setCustomValidity(
      invalid
        ? i18n("discourse_ai.discourse_workflows.ai_tool.invalid_json")
        : ""
    );
  });

  #draft = tracked(null);

  get serializedValue() {
    return this.args.field.value == null
      ? ""
      : JSON.stringify(this.args.field.value, null, 2);
  }

  get draft() {
    const draft = this.#draft.value;
    return draft?.serializedValue === this.serializedValue ? draft : null;
  }

  @action
  revert() {
    this.#draft.value = null;
  }

  @action
  update(event) {
    const text = event.target.value;
    const value = parseJson(text, this.args.type);
    const invalid = Boolean(text.trim()) && value === undefined;
    this.#draft.value = {
      text,
      invalid,
      serializedValue: invalid
        ? this.serializedValue
        : value === undefined
          ? ""
          : JSON.stringify(value, null, 2),
    };
    if (!invalid) {
      this.args.field.set(value);
    }
  }

  <template>
    <DExpandingTextArea
      aria-describedby={{if
        this.draft.invalid
        (concat @field.id "-invalid-json")
        @field.describedBy
      }}
      aria-invalid={{if (or this.draft.invalid @field.error) "true"}}
      class="form-kit__control-textarea"
      disabled={{@field.disabled}}
      id={{@field.id}}
      name={{@field.name}}
      @value={{if this.draft this.draft.text this.serializedValue}}
      {{on "input" this.update}}
      {{this.syncValidity this.draft.invalid}}
    />
    {{#if this.draft.invalid}}
      <p class="form-kit__meta" id={{concat @field.id "-invalid-json"}}>
        {{i18n "discourse_ai.discourse_workflows.ai_tool.invalid_json"}}
      </p>
      <DButton
        class="btn-flat"
        @action={{this.revert}}
        @label="discourse_ai.discourse_workflows.ai_tool.revert_json"
      />
    {{/if}}
  </template>
}

class StringListInput extends Component {
  get values() {
    return Array.isArray(this.args.field.value) ? this.args.field.value : [];
  }

  @action
  add() {
    this.args.field.set([...this.values, ""]);
  }

  @action
  remove(index) {
    this.args.field.set(
      this.values.filter((_, position) => position !== index)
    );
  }

  @action
  update(index, event) {
    this.args.field.set(this.values.with(index, event.target.value));
  }

  <template>
    <div
      aria-labelledby={{@field.labelId}}
      class="ai-tool-arguments__list"
      role="group"
    >
      {{#each this.values key="@index" as |value index|}}
        <div class="ai-tool-arguments__list-row">
          <input
            aria-label={{i18n
              "discourse_ai.discourse_workflows.ai_tool.list_item"
            }}
            class="form-kit__control-input"
            disabled={{@field.disabled}}
            type="text"
            value={{value}}
            {{on "input" (fn this.update index)}}
          />
          <DButton
            class="btn-flat"
            @action={{fn this.remove index}}
            @disabled={{@field.disabled}}
            @icon="trash-can"
            @title="discourse_ai.discourse_workflows.ai_tool.remove_list_item"
          />
        </div>
      {{/each}}
      <DButton
        class="btn-default ai-tool-arguments__add-item"
        @action={{this.add}}
        @disabled={{@field.disabled}}
        @icon="plus"
        @label="discourse_ai.discourse_workflows.ai_tool.add_list_item"
      />
    </div>
  </template>
}

export default class AiToolArguments extends Component {
  @service workflowsNodeTypes;

  loadArguments = modifier((_element, [signatureKey]) => {
    let active = true;
    const context = {
      path: this.args.fieldName,
      currentNodeParameters: JSON.parse(signatureKey),
    };
    this.workflowsNodeTypes
      .loadNodeParameterOptions(
        this.args.nodeDefinition?.name || this.args.node.type,
        "tool_arguments",
        this.args.nodeDefinition?.version || this.args.node.typeVersion,
        context
      )
      .then((result) => {
        if (active) {
          this.#loaded.value = {
            signatureKey,
            rows: (Array.isArray(result) ? result : []).map((argument) => ({
              ...argument,
              compound:
                ["array", "object"].includes(argument.type) &&
                !argument.enum?.length,
              stringList:
                argument.type === "array" && argument.item_type === "string",
              schema: schemaForArgument(argument),
            })),
          };
        }
      });
    return () => (active = false);
  });

  #loaded = tracked(null);

  @cached
  get signatureKey() {
    const keys = this.args.schema?.control_options?.signature_parameters || [
      "tool_ref",
    ];
    const values = keys.map((key) => [key, this.args.nodeParameters?.[key]]);
    return values.every(([, value]) => value)
      ? JSON.stringify(Object.fromEntries(values))
      : null;
  }

  get signature() {
    const loaded = this.#loaded.value;
    return loaded?.signatureKey === this.signatureKey ? loaded : null;
  }

  get rawValue() {
    return this.args.configuration?.[this.args.fieldName];
  }

  get value() {
    return isObject(this.rawValue) ? this.rawValue : {};
  }

  get invalidArguments() {
    return this.rawValue != null && !isObject(this.rawValue);
  }

  get usesJsonEditor() {
    return this.signature?.rows.some(
      ({ name, enum: values }) =>
        !name ||
        /[.-]/.test(name) ||
        Object.hasOwn(Object.prototype, name) ||
        values?.some((value) => typeof value === "object")
    );
  }

  get staleKeys() {
    const names = new Set(this.signature?.rows.map(({ name }) => name));
    return Object.keys(this.value).filter((name) => !names.has(name));
  }

  @action
  setArgument(row, value) {
    if (row.compound && typeof value === "string") {
      const previous = this.value[row.name];
      if (!isExpression(value)) {
        const literal =
          typeof previous === "string"
            ? (previous.match(/^=\{\{\s*([\s\S]*?)\s*\}\}$/)?.[1] ?? value)
            : value;
        value = parseJson(literal, row.type);
      } else if (
        row.type === "object" &&
        isObject(previous) &&
        value === `=${JSON.stringify(previous, null, 2)}`
      ) {
        value = `={{ ${value.slice(1)} }}`;
      }
    }

    if (value == null) {
      return this.removeArgument(row.name);
    }
    if (row.schema.choices && !isExpression(value)) {
      value = row.schema.choices.find(
        (choice) => String(choice) === String(value)
      );
      if (value === undefined) {
        return this.removeArgument(row.name);
      }
    }

    this.args.formApi.set(this.args.fieldName, {
      ...this.value,
      [row.name]: value,
    });
  }

  @action
  removeArgument(name) {
    if (Object.hasOwn(this.value, name)) {
      const updated = { ...this.value };
      delete updated[name];
      this.args.formApi.set(this.args.fieldName, updated);
    }
  }

  @action
  clearInvalidArguments() {
    this.args.formApi.set(this.args.fieldName, {});
  }

  <template>
    {{#if this.signatureKey}}
      <div class="ai-tool-arguments" {{this.loadArguments this.signatureKey}}>
        {{#if
          (or
            (not this.signature)
            this.signature.rows.length
            this.staleKeys.length
            this.invalidArguments
          )
        }}
          <@form.Section @title={{@label}}>
            {{#if (not this.signature)}}
              <p>{{i18n
                  "discourse_ai.discourse_workflows.ai_tool.loading_arguments"
                }}</p>
            {{else if this.invalidArguments}}
              <@form.Alert @type="warning">
                {{i18n
                  "discourse_ai.discourse_workflows.ai_tool.invalid_arguments"
                }}
                <DButton
                  class="btn-default"
                  @action={{this.clearInvalidArguments}}
                  @label="discourse_ai.discourse_workflows.ai_tool.clear_arguments"
                />
              </@form.Alert>
            {{else if this.usesJsonEditor}}
              <@form.Field
                class="ai-tool-arguments__compound"
                @description={{i18n
                  "discourse_ai.discourse_workflows.ai_tool.json_arguments_description"
                }}
                @name={{@fieldName}}
                @title={{i18n
                  "discourse_ai.discourse_workflows.ai_tool.json_arguments"
                }}
                @type="custom"
                as |field|
              >
                <field.Control>
                  <JsonInput @field={{field}} @type="object" />
                </field.Control>
              </@form.Field>
              <ul>
                {{#each this.signature.rows key="name" as |row|}}
                  <li><code>{{row.name}}</code>{{#if row.description}}
                      —
                      {{row.description}}{{/if}}</li>
                {{/each}}
              </ul>
            {{else}}
              <@form.Object @name={{@fieldName}} as |object item|>
                {{#each this.signature.rows key="name" as |row|}}
                  {{#if row.compound}}
                    <object.Field
                      class="ai-tool-arguments__compound"
                      @description={{row.description}}
                      @name={{row.name}}
                      @onSet={{fn this.setArgument row}}
                      @title={{row.name}}
                      @type="custom"
                      @validation={{if row.required "required"}}
                      as |field|
                    >
                      <field.Control>
                        <@ExpressionWrapper
                          @field={{field}}
                          @schema={{row.schema}}
                          @session={{@session}}
                          @supportsExpression={{true}}
                        >
                          {{#if row.stringList}}
                            <StringListInput @field={{field}} />
                          {{else}}
                            <JsonInput @field={{field}} @type={{row.type}} />
                          {{/if}}
                        </@ExpressionWrapper>
                      </field.Control>
                    </object.Field>
                  {{else}}
                    <@Field
                      @configuration={{item}}
                      @fieldName={{row.name}}
                      @form={{object}}
                      @label={{row.name}}
                      @onSet={{fn this.setArgument row}}
                      @schema={{row.schema}}
                      @session={{@session}}
                    />
                    {{#if row.description}}
                      <p
                        class="form-kit__container-description"
                      >{{row.description}}</p>
                    {{/if}}
                  {{/if}}
                {{/each}}
              </@form.Object>
              {{#each this.staleKeys as |name|}}
                <@form.Alert @type="warning">
                  {{i18n
                    "discourse_ai.discourse_workflows.ai_tool.stale_argument"
                    name=name
                  }}
                  <DButton
                    class="btn-default"
                    @action={{fn this.removeArgument name}}
                    @label="discourse_ai.discourse_workflows.ai_tool.remove_argument"
                  />
                </@form.Alert>
              {{/each}}
            {{/if}}
          </@form.Section>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
