import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dDragAndDropMonitor from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class MonitorExample extends Component {
  @tracked entries = [];

  @action
  logDrop() {
    this.#log("onDrop");
  }

  @action
  logStart() {
    this.#log("onDragStart");
  }

  #log(name) {
    this.entries = [...this.entries, name].slice(-6);
  }

  <template>
    <div
      class="styleguide-drag-and-drop"
      {{dDragAndDropMonitor
        types="card"
        onDragStart=this.logStart
        onDrop=this.logDrop
      }}
    >
      <div
        class="styleguide-drag-and-drop__chip"
        {{dDragAndDropSource type="card"}}
      >{{i18n "styleguide.sections.drag_and_drop.drag_me"}}</div>

      <div
        class="styleguide-drag-and-drop__zone"
        {{dDragAndDropTarget accepts="card"}}
      >{{i18n "styleguide.sections.drag_and_drop.drop_here"}}</div>

      <ol class="styleguide-drag-and-drop__log styleguide-example__result">
        {{#each this.entries key="@index" as |entry|}}
          <li>{{entry}}</li>
        {{/each}}
      </ol>
    </div>
  </template>
}
