import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { fn } from "@ember/helper";

export default class PlaceholdersList extends Component {
  <template>
    <div class="placeholders-list">
      {{#each @placeholders as |placeholder|}}
        <DButton
          @translatedLabel={{placeholder}}
          class="placeholder-item"
          @action={{fn this.copyPlaceholder placeholder}}
        />
      {{/each}}
    </div>
  </template>

  @action
  copyPlaceholder(placeholder) {
    this.args.onCopy(
      `${this.args.currentValue} %%${placeholder.toUpperCase()}%%`
    );
  }
}
