import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class AiAgentCollapsableExample extends Component {
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
    return i18n("discourse_ai.ai_agent.examples.collapsable_title", {
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
              "discourse_ai.ai_agent.examples."
              (if (eq pairIdx 0) "user" "model")
            )
          }}
          @validation="required|length:1,5000"
          @disabled={{@system}}
          @type="textarea"
          as |field|
        >
          <field.Control />
        </exPair.Field>
      </@examplesCollection.Collection>

      {{#unless @system}}
        <@form.Container>
          <@form.Button
            @action={{this.deletePair}}
            @label="discourse_ai.ai_agent.examples.remove"
            class="ai-agent-editor__delete_example btn-danger"
          />
        </@form.Container>
      {{/unless}}
    {{/unless}}
  </template>
}
