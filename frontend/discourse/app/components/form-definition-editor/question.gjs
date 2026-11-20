import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import {
  fieldTypes,
  hasChoices,
  hasPlaceholder,
  newChoice,
} from "discourse/lib/form-definition";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";
import { itemLabel, remove, reorder } from "./list.js";

export default class FormQuestionEditor extends Component {
  @action
  changeType(question, path, type, { set }) {
    const next = { ...question, type };
    if (hasChoices(type)) {
      next.choices ??= [newChoice()];
    } else {
      delete next.choices;
    }
    if (!hasPlaceholder(type)) {
      delete next.placeholder;
    }
    set(path, next);
  }

  canRemoveChoice(question) {
    return question.choices.length > 1;
  }

  @action
  addChoice(form, path) {
    form.addItemToCollection(path + ".choices", newChoice());
  }

  <template>
    <@editor.Field
      @name="label"
      @title={{i18n "form_definition.label"}}
      @type="input"
      @validation="required:trim"
      as |field|
    >
      <field.Control maxlength="255" />
    </@editor.Field>
    <@editor.Field
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
    {{#if (hasPlaceholder @question.type)}}
      <@editor.Field
        @name="placeholder"
        @title={{i18n "form_definition.placeholder"}}
        @type="input"
        as |field|
      >
        <field.Control maxlength="255" />
      </@editor.Field>
    {{/if}}
    <@editor.Field
      @name="required"
      @title={{i18n "form_definition.required"}}
      @type="checkbox"
      as |control|
    ><control.Control /></@editor.Field>
    {{#if (hasChoices @question.type)}}
      <@editor.Object @name="choices" as |choices|>
        <DReorderableList
          @items={{@question.choices}}
          @key="id"
          @label={{itemLabel}}
          @onMove={{fn reorder @form.set (concat @path ".choices")}}
          @onRemove={{fn
            remove
            @form.set
            (concat @path ".choices")
            @question.choices
          }}
          @removable={{fn this.canRemoveChoice @question}}
        >
          <:row as |choice choiceRow|>
            {{#each (array choiceRow.index) as |choiceIndex|}}
              <choices.Object @name={{concat "" choiceIndex}} as |option|>
                <option.Field
                  @name="label"
                  @title={{i18n "form_definition.choice"}}
                  @type="input"
                  @validation="required:trim"
                  as |field|
                >
                  <field.Control maxlength="255" />
                </option.Field>
              </choices.Object>
            {{/each}}
          </:row>
        </DReorderableList>
      </@editor.Object>
      <@form.Button
        @action={{fn this.addChoice @form @path}}
        @disabled={{gte @question.choices.length 100}}
        @label="form_definition.add_choice"
      />
    {{/if}}
  </template>
}
