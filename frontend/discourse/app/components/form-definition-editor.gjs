import { concat, fn } from "@ember/helper";
import Form from "discourse/components/form";
import { newFormField } from "discourse/lib/form-definition";
import { DFloatingControlBarLayout } from "discourse/ui-kit/d-floating-control-bar";
import FieldList from "./form-definition-editor/field-list.gjs";
import { itemLabel } from "./form-definition-editor/list.js";
import FormQuestionEditor from "./form-definition-editor/question.gjs";

export { default as ChoiceList } from "./form-definition-editor/choice-list.gjs";
export { FieldList };

const newField = (fieldTypes) => newFormField(fieldTypes?.[0]);

export default <template>
  <Form
    class="form-definition-editor"
    @data={{@definition}}
    @onSubmit={{@onSave}}
    @validate={{@validate}}
    as |form draft|
  >
    {{yield form to="details"}}
    <FieldList
      @fields={{draft.fields}}
      @form={{form}}
      @key="id"
      @labelFor={{itemLabel}}
      @limit={{100}}
      @minimum={{@minimumFields}}
      @newField={{fn newField @fieldTypes}}
      @onChange={{fn form.set "fields"}}
      as |question index Header|
    >
      {{#each (array index) as |formIndex|}}
        {{#let (concat "fields." formIndex) as |path|}}
          <form.Object @name={{path}} as |editor|>
            <FormQuestionEditor
              @editor={{editor}}
              @fieldTypes={{@fieldTypes}}
              @form={{form}}
              @Header={{Header}}
              @path={{path}}
              @question={{question}}
            />
          </form.Object>
        {{/let}}
      {{/each}}
    </FieldList>
    {{#let
      (if
        @floatingActions
        (component DFloatingControlBarLayout widthSource=@actionsWidthSource)
        form.Actions
      )
      as |Actions|
    }}
      <Actions>
        <form.Submit @label="save" />
        {{#if @onPreview}}
          <form.Button
            class="btn-default form-definition-editor__preview"
            @action={{fn @onPreview draft}}
            @icon="eye"
            @label="form_definition.preview"
          />
        {{/if}}
        {{yield to="additionalActions"}}
      </Actions>
    {{/let}}
  </Form>
</template>
