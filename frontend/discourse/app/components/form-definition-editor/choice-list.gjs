import Component from "@glimmer/component";
import { action } from "@ember/object";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import { i18n } from "discourse-i18n";

const INDEX_KEY = "@index";
const choiceLabel = (index) =>
  i18n("form_definition.choice_number", { number: index + 1 });

export default class ChoiceList extends Component {
  @action
  add() {
    return this.args.onChange([...this.args.choices, this.args.newChoice()]);
  }

  @action
  move({ proposedToItems }) {
    return this.args.onChange(proposedToItems);
  }

  @action
  remove(choice, index) {
    return this.args.onChange(this.args.choices.filter((_, i) => i !== index));
  }

  @action
  canRemove() {
    return this.args.choices.length > (this.args.minimum ?? 0);
  }

  <template>
    <@form.Fieldset @title={{@title}}>
      <DReorderableList
        @items={{@choices}}
        @key={{or @key INDEX_KEY}}
        @label={{@labelFor}}
        @onMove={{this.move}}
        @onRemove={{this.remove}}
        @removable={{this.canRemove}}
      >
        <:row as |choice row|>
          {{#each (array row.index) as |index|}}
            {{yield choice index (choiceLabel index)}}
          {{/each}}
        </:row>
      </DReorderableList>
    </@form.Fieldset>
    <@form.Actions>
      <@form.Button
        class="btn-default form-definition-editor__add-choice"
        @action={{this.add}}
        @disabled={{and @limit (gte @choices.length @limit)}}
        @icon="plus"
        @label="form_definition.add_choice"
      />
    </@form.Actions>
  </template>
}
