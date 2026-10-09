import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class HandleExample extends Component {
  @tracked gripElement;
  @tracked landed = false;

  /** The grip element itself; `dragHandle` takes the element, never a selector. */
  captureGrip = modifier((element) => {
    this.gripElement = element;
    return () => (this.gripElement = undefined);
  });

  @action
  onDrop() {
    this.landed = true;
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div
        class="styleguide-drag-and-drop__chip --with-grip"
        {{dDragAndDropSource type="card" dragHandle=this.gripElement}}
      >
        <span
          aria-hidden="true"
          class="styleguide-drag-and-drop__grip"
          {{this.captureGrip}}
        >{{dIcon "grip-vertical"}}</span>
        {{i18n "styleguide.sections.drag_and_drop.selectable_text"}}
      </div>

      <div
        class="styleguide-drag-and-drop__zone"
        {{dDragAndDropTarget
          accepts="card"
          position="inside"
          onDrop=this.onDrop
        }}
      >{{i18n "styleguide.sections.drag_and_drop.drop_here"}}</div>

      <p class="styleguide-example__result">
        {{#if this.landed}}
          {{i18n "styleguide.sections.drag_and_drop.handle_landed"}}
        {{else}}
          {{i18n "styleguide.sections.drag_and_drop.nothing_yet"}}
        {{/if}}
      </p>
    </div>
  </template>
}
