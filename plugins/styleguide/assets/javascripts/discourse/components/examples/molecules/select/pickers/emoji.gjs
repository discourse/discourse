import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import DSelect from "discourse/ui-kit/select/d-select";
import { EMOJI } from "../../../../../lib/select-fixtures";

export default class EmojiSelectExample extends Component {
  @tracked value = "tada";

  @action
  update(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @identifier="sg-emoji"
      @items={{EMOJI}}
      @value={{this.value}}
      @onChange={{this.update}}
      @groupBy="group"
      @variant="button"
    >
      <:selection as |item|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dEmoji item.name}}
          {{item.name}}
        </span>
      </:selection>

      <:item as |item|>
        <span class="select-examples__row select-examples__row--glyph">
          {{dEmoji item.name}}
          <span class="select-examples__primary">{{item.name}}</span>
          <code class="select-showcases__shortcode" aria-hidden="true">
            :{{item.name}}:
          </code>
        </span>
      </:item>
    </DSelect>
  </template>
}
