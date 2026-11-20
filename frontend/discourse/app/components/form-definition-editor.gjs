import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import Form from "discourse/components/form";
import { newQuestion } from "discourse/lib/form-definition";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";
import { itemLabel, remove, reorder } from "./form-definition-editor/list.js";
import FormQuestionEditor from "./form-definition-editor/question.gjs";

export default class FormDefinitionEditor extends Component {
  @action
  addField(form) {
    form.addItemToCollection("fields", newQuestion(this.args.fieldTypes?.[0]));
  }

  <template>
    <Form
      class="form-definition-editor"
      @data={{@definition}}
      @onSubmit={{@onSave}}
      as |form draft|
    >
      <form.Field
        @name="title"
        @title={{i18n "form_definition.title"}}
        @type="input"
        @validation="required:trim"
        as |field|
      >
        <field.Control maxlength="255" />
      </form.Field>
      <form.Field
        @name="description"
        @title={{i18n "form_definition.description"}}
        @type="textarea"
        as |field|
      >
        <field.Control maxlength="2000" />
      </form.Field>
      <form.Object @name="fields" as |questions|>
        <DReorderableList
          @items={{draft.fields}}
          @key="id"
          @label={{itemLabel}}
          @onMove={{fn reorder form.set "fields"}}
          @onRemove={{fn remove form.set "fields" draft.fields}}
        >
          <:row as |question row|>
            {{#each (array row.index) as |index|}}
              {{#let (concat "fields." index) as |path|}}
                <questions.Object @name={{concat "" index}} as |editor|>
                  <FormQuestionEditor
                    @editor={{editor}}
                    @fieldTypes={{@fieldTypes}}
                    @form={{form}}
                    @path={{path}}
                    @question={{question}}
                  />
                </questions.Object>
              {{/let}}
            {{/each}}
          </:row>
        </DReorderableList>
      </form.Object>
      <form.Button
        class="form-definition-editor__add"
        @action={{fn this.addField form}}
        @disabled={{gte draft.fields.length 100}}
        @icon="plus"
        @label="form_definition.add_field"
      />
      <form.Actions>
        <form.Submit @label="save" />
        {{#if @onPreview}}
          <form.Button
            class="form-definition-editor__preview"
            @action={{fn @onPreview draft}}
            @icon="eye"
            @label="form_definition.preview"
          />
        {{/if}}
      </form.Actions>
    </Form>
  </template>
}
