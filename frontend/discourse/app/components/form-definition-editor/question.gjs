import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import {
  fieldTypes,
  hasChoices,
  hasPlaceholder,
  initialChoices,
  newChoice,
} from "discourse/lib/form-definition";
import { i18n } from "discourse-i18n";
import ChoiceList from "./choice-list.gjs";
import { itemLabel, limitText } from "./list.js";

const hasAttribute = Object.hasOwn;

export default class FormQuestionEditor extends Component {
  @action
  toggleTextAttribute(name) {
    const question = { ...this.args.question };
    if (hasAttribute(question, name)) {
      delete question[name];
    } else {
      question[name] = "";
    }
    this.args.form.set(this.args.path, question);
  }

  @action
  changeType(question, path, type, { set }) {
    if (type === "display_text") {
      set(path, {
        id: question.id,
        type,
        content: question.content ?? question.label ?? "",
      });
      return;
    }
    const next =
      question.type === "display_text"
        ? {
            id: question.id,
            type,
            label: limitText(
              question.content.trim().split(/[\r\n\u2028\u2029]/u, 1)[0],
              255
            ),
            required: false,
          }
        : { ...question, type };
    if (hasChoices(type)) {
      next.choices ??= initialChoices();
    } else {
      delete next.choices;
    }
    if (!hasPlaceholder(type)) {
      delete next.placeholder;
    }
    set(path, next);
  }

  <template>
    {{#if (eq @question.type "display_text")}}
      <@Header />
    {{else}}
      <@Header
        @onSetRequired={{fn @form.set (concat @path ".required")}}
        @required={{@question.required}}
        as |Attribute|
      >
        <Attribute
          data-field-attribute="description"
          @active={{hasAttribute @question "description"}}
          @label={{i18n "form_definition.description"}}
          @onToggle={{fn this.toggleTextAttribute "description"}}
        />
        {{#if (hasPlaceholder @question.type)}}
          <Attribute
            data-field-attribute="placeholder"
            @active={{hasAttribute @question "placeholder"}}
            @label={{i18n "form_definition.placeholder"}}
            @onToggle={{fn this.toggleTextAttribute "placeholder"}}
          />
        {{/if}}
      </@Header>
    {{/if}}
    <@editor.Field
      @format="full"
      @name="type"
      @onSet={{fn this.changeType @question @path}}
      @title={{i18n "form_definition.type"}}
      @type="select"
      as |field|
    >
      <field.Control @includeNone={{false}} as |select|>
        {{#each (or @fieldTypes fieldTypes) as |type|}}
          <select.Option @value={{type}}>{{i18n
              (concat "form_definition.types." type)
            }}</select.Option>
        {{/each}}
      </field.Control>
    </@editor.Field>
    {{#if (eq @question.type "display_text")}}
      <@editor.Field
        @format="full"
        @name="content"
        @title={{i18n "form_definition.text_content"}}
        @type="textarea"
        @validation="required:trim"
        as |field|
      >
        <field.Control maxlength="2000" />
      </@editor.Field>
    {{else}}
      <@editor.Field
        @format="full"
        @name="label"
        @title={{i18n "form_definition.label"}}
        @type="input"
        @validation="required:trim|length:1,255"
        as |field|
      >
        <field.Control maxlength="255" />
      </@editor.Field>
    {{/if}}
    {{#if (hasAttribute @question "description")}}
      <@editor.Field
        @format="full"
        @name="description"
        @title={{i18n "form_definition.description"}}
        @type="input"
        as |field|
      >
        <field.Control maxlength="2000" />
      </@editor.Field>
    {{/if}}
    {{#if
      (and
        (hasPlaceholder @question.type) (hasAttribute @question "placeholder")
      )
    }}
      <@editor.Field
        @format="full"
        @name="placeholder"
        @title={{i18n "form_definition.placeholder"}}
        @type="input"
        as |field|
      >
        <field.Control maxlength="255" />
      </@editor.Field>
    {{/if}}
    {{#if (hasChoices @question.type)}}
      <ChoiceList
        @choices={{@question.choices}}
        @form={{@form}}
        @key="id"
        @labelFor={{itemLabel}}
        @limit={{100}}
        @minimum={{1}}
        @newChoice={{newChoice}}
        @onChange={{fn @form.set (concat @path ".choices")}}
        @title={{i18n "form_definition.choices"}}
        as |choice index label|
      >
        <@form.Object @name={{concat @path ".choices." index}} as |option|>
          <option.Field
            @format="full"
            @name="label"
            @showTitle={{false}}
            @title={{label}}
            @type="input"
            @validation="required:trim"
            as |field|
          >
            <field.Control aria-label={{label}} maxlength="255" />
          </option.Field>
        </@form.Object>
      </ChoiceList>
    {{/if}}
  </template>
}
