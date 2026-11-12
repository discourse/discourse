import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class DisabledExample extends Component {
  @tracked draggable = true;

  // The switch reads as the state it is in, so it is held positively here and
  // inverted for the modifier rather than the other way round.
  get disabled() {
    return !this.draggable;
  }

  @action
  toggle() {
    this.draggable = !this.draggable;
  }

  <template>
    <div class="styleguide-drag-and-drop">
      {{! The control sits beside the source it governs, not after the target:
      it is the first thing the instruction asks the reader to touch. }}
      <div class="styleguide-drag-and-drop__controls">
        <div
          class="styleguide-drag-and-drop__chip"
          {{dDragAndDropSource type="card" disabled=this.disabled}}
        >{{i18n "styleguide.sections.drag_and_drop.drag_me"}}</div>

        <DToggleSwitch
          @state={{this.draggable}}
          @translatedLabel={{i18n
            "styleguide.sections.drag_and_drop.draggable"
          }}
          {{on "click" this.toggle}}
        />
      </div>

      <div
        class="styleguide-drag-and-drop__zone"
        {{dDragAndDropTarget accepts="card" position="inside"}}
      >{{i18n "styleguide.sections.drag_and_drop.drop_here"}}</div>
    </div>
  </template>
}
