import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

const COLUMNS = ["one", "two", "three"];

export default class AxisExample extends Component {
  @tracked position;

  @action
  onDrop({ position }) {
    this.position = position;
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div
        class="styleguide-drag-and-drop__chip"
        {{dDragAndDropSource type="card"}}
      >{{i18n "styleguide.sections.drag_and_drop.drag_me"}}</div>

      <div class="styleguide-drag-and-drop__columns">
        {{#each COLUMNS key="@index" as |column|}}
          <div
            class="styleguide-drag-and-drop__column"
            {{dDragAndDropTarget
              accepts="card"
              axis="horizontal"
              onDrop=this.onDrop
            }}
          >{{column}}</div>
        {{/each}}
      </div>

      <p class="styleguide-example__result">
        {{#if this.position}}
          {{i18n
            "styleguide.sections.drag_and_drop.reported_position"
            position=this.position
          }}
        {{else}}
          {{i18n "styleguide.sections.drag_and_drop.nothing_yet"}}
        {{/if}}
      </p>
    </div>
  </template>
}
