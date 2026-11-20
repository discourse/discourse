import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import DCharCounter from "discourse/ui-kit/d-char-counter";

export default class CharCounterExample extends Component {
  @tracked content = "";

  @action
  updateContent(value) {
    this.content = value;
  }

  <template>
    <DCharCounter @max="50" @value={{this.content}}>
      <textarea
        class="styleguide--char-counter"
        {{on "input" (withEventValue this.updateContent)}}
      ></textarea>
    </DCharCounter>
  </template>
}
