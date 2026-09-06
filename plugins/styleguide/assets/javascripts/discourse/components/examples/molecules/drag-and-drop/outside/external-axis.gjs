import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import { i18n } from "discourse-i18n";

export default class ExternalAxisExample extends Component {
  @tracked position;

  @action
  onDrop({ position }) {
    this.position = position;
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div
        class="styleguide-drag-and-drop__zone"
        {{dDragAndDropExternalTarget
          accepts=(array "urls" "text")
          axis="vertical"
          onDrop=this.onDrop
        }}
      >{{i18n "styleguide.sections.drag_and_drop.a_slot"}}</div>

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
