import Component from "@glimmer/component";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import { i18n } from "discourse-i18n";

export default class ServiceExample extends Component {
  @service dragAndDrop;

  // Read through a getter rather than calling the service method from the
  // template: it is an ordinary method, so a template call would invoke it
  // detached from the service.
  get isArmed() {
    return this.dragAndDrop.accepts("card");
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div
        class="styleguide-drag-and-drop__chip"
        {{dDragAndDropSource type="card"}}
      >{{i18n "styleguide.sections.drag_and_drop.drag_me"}}</div>

      {{! No callbacks: the panel renders straight from tracked state. }}
      <div
        class={{dConcatClass
          "styleguide-drag-and-drop__panel"
          (if this.isArmed "--armed")
        }}
      >
        {{#if this.isArmed}}
          {{i18n "styleguide.sections.drag_and_drop.armed"}}
        {{else}}
          {{i18n "styleguide.sections.drag_and_drop.idle"}}
        {{/if}}
      </div>
    </div>
  </template>
}
