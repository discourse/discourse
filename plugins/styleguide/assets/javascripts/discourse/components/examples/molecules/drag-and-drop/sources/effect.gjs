import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class EffectExample extends Component {
  @tracked effect;

  /** The effect a target asked for is recorded on the drag's own record of it. */
  @action
  onDrop({ location }) {
    this.effect = location.current.dropTargets[0]?.dropEffect;
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div
        class="styleguide-drag-and-drop__chip"
        {{dDragAndDropSource
          type="card"
          effectAllowed="copyMove"
          onDrop=this.onDrop
        }}
      >{{i18n "styleguide.sections.drag_and_drop.drag_me"}}</div>

      <div class="styleguide-drag-and-drop__chips">
        <div
          class="styleguide-drag-and-drop__zone"
          {{dDragAndDropTarget
            accepts="card"
            position="inside"
            dropEffect="copy"
          }}
        >{{i18n "styleguide.sections.drag_and_drop.asks_for_copy"}}</div>

        <div
          class="styleguide-drag-and-drop__zone"
          {{dDragAndDropTarget
            accepts="card"
            position="inside"
            dropEffect="move"
          }}
        >{{i18n "styleguide.sections.drag_and_drop.asks_for_move"}}</div>
      </div>

      <p class="styleguide-example__result">
        {{#if this.effect}}
          {{i18n
            "styleguide.sections.drag_and_drop.recorded_effect"
            effect=this.effect
          }}
        {{else}}
          {{i18n "styleguide.sections.drag_and_drop.nothing_yet"}}
        {{/if}}
      </p>
    </div>
  </template>
}
