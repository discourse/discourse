import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class AcceptsSelfExample extends Component {
  @tracked landed;

  @action
  onDrop({ source }) {
    this.landed = source.data.name;
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div class="styleguide-drag-and-drop__chips">
        <div
          class="styleguide-drag-and-drop__chip --dual"
          {{dDragAndDropSource type="card" data=(hash name="A")}}
          {{dDragAndDropTarget
            accepts="card"
            axis="horizontal"
            acceptsSelf=false
            onDrop=this.onDrop
          }}
        >{{i18n "styleguide.sections.drag_and_drop.card_a"}}</div>

        <div
          class="styleguide-drag-and-drop__chip --dual"
          {{dDragAndDropSource type="card" data=(hash name="B")}}
          {{dDragAndDropTarget
            accepts="card"
            axis="horizontal"
            acceptsSelf=false
            onDrop=this.onDrop
          }}
        >{{i18n "styleguide.sections.drag_and_drop.card_b"}}</div>
      </div>

      <p class="styleguide-example__result">
        {{#if this.landed}}
          {{i18n
            "styleguide.sections.drag_and_drop.dropped_card"
            name=this.landed
          }}
        {{else}}
          {{i18n "styleguide.sections.drag_and_drop.nothing_yet"}}
        {{/if}}
      </p>
    </div>
  </template>
}
