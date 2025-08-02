import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AiPersonaCollapsableExample extends Component {
  @tracked collapsed = true;

  get caretIcon() {
    return this.collapsed ? "angle-right" : "angle-down";
  }

  @action
  toggleExample() {
    this.collapsed = !this.collapsed;
  }

  @action
  deletePair() {
    this.collapsed = true;
    this.args.examplesCollection.remove(this.args.exampleNumber);
  }

  get exampleTitle() {
    return i18n("discourse_ai.ai_persona.examples.collapsable_title", {
      number: this.args.exampleNumber + 1,
    });
  }

  <template>
    <div role="button" {{on "click" this.toggleExample}}>
      <span>{{icon this.caretIcon}}</span>
      {{this.exampleTitle}}
    </div>
    {{#unless this.collapsed}}
      <@examplesCollection.Collection as |exPair pairIdx|>
        <exPair.Field
          @title={{i18n
            (concat
              "discourse_ai.ai_persona.examples."
              (if (eq pairIdx 0) "user" "model")
            )
          }}
          @validation="required|length:1,5000"
          @disabled={{@system}}
          as |field|
        >
          <field.Textarea />
        </exPair.Field>
      </@examplesCollection.Collection>

      {{#unless @system}}
        <@form.Container>
          <@form.Button
            @action={{this.deletePair}}
            @label="discourse_ai.ai_persona.examples.remove"
            class="ai-persona-editor__delete_example btn-danger"
          />
        </@form.Container>
      {{/unless}}
    {{/unless}}
  </template>
}
