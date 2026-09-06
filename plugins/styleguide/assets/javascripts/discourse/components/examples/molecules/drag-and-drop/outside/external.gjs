import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import { i18n } from "discourse-i18n";

export default class ExternalExample extends Component {
  @tracked summary;

  @action
  onDrop({ source }) {
    this.summary = source.containsFiles()
      ? source
          .getFiles()
          .map((file) => file.name)
          .join(", ")
      : (source.getURLs()[0] ?? source.getText());
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div
        class="styleguide-drag-and-drop__zone"
        {{dDragAndDropExternalTarget
          accepts=(array "urls" "text" "files")
          onDrop=this.onDrop
        }}
      >{{i18n "styleguide.sections.drag_and_drop.from_outside"}}</div>

      <p class="styleguide-example__result">
        {{#if this.summary}}
          {{this.summary}}
        {{else}}
          {{i18n "styleguide.sections.drag_and_drop.nothing_yet"}}
        {{/if}}
      </p>
    </div>
  </template>
}
