import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class TypesExample extends Component {
  @tracked landed;

  @action
  onDrop({ source }) {
    this.landed = source.data.label;
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div class="styleguide-drag-and-drop__chips">
        <div
          class="styleguide-drag-and-drop__chip"
          {{dDragAndDropSource
            type="card"
            data=(hash label=(i18n "styleguide.sections.drag_and_drop.a_card"))
          }}
        >{{i18n "styleguide.sections.drag_and_drop.a_card"}}</div>

        <div
          class="styleguide-drag-and-drop__chip"
          {{dDragAndDropSource
            type="note"
            data=(hash label=(i18n "styleguide.sections.drag_and_drop.a_note"))
          }}
        >{{i18n "styleguide.sections.drag_and_drop.a_note"}}</div>
      </div>

      <div
        class="styleguide-drag-and-drop__zone"
        {{dDragAndDropTarget
          accepts="card"
          position="inside"
          onDrop=this.onDrop
        }}
      >{{i18n "styleguide.sections.drag_and_drop.cards_only"}}</div>

      <p class="styleguide-example__result">
        {{#if this.landed}}
          {{i18n "styleguide.sections.drag_and_drop.landed" label=this.landed}}
        {{else}}
          {{i18n "styleguide.sections.drag_and_drop.nothing_yet"}}
        {{/if}}
      </p>
    </div>
  </template>
}
