import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class NestingExample extends Component {
  @tracked landedOn;

  @action
  record(name) {
    this.landedOn = name;
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div
        class="styleguide-drag-and-drop__chip"
        {{dDragAndDropSource type="card"}}
      >{{i18n "styleguide.sections.drag_and_drop.drag_me"}}</div>

      <div
        class="styleguide-drag-and-drop__zone --outer"
        {{dDragAndDropTarget
          accepts="card"
          position="inside"
          onDrop=(fn this.record "outer")
        }}
      >
        {{i18n "styleguide.sections.drag_and_drop.outer"}}
        <div
          class="styleguide-drag-and-drop__zone --inner"
          {{dDragAndDropTarget
            accepts="card"
            position="inside"
            onDrop=(fn this.record "inner")
          }}
        >{{i18n "styleguide.sections.drag_and_drop.inner"}}</div>
      </div>

      <p class="styleguide-example__result">
        {{#if this.landedOn}}
          {{i18n
            "styleguide.sections.drag_and_drop.received_by"
            name=this.landedOn
          }}
        {{else}}
          {{i18n "styleguide.sections.drag_and_drop.nothing_yet"}}
        {{/if}}
      </p>
    </div>
  </template>
}
