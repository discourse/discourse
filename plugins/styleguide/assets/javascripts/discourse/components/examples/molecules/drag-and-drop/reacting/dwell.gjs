import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import dDragDwell from "discourse/ui-kit/modifiers/d-drag-dwell";
import { i18n } from "discourse-i18n";

const ROWS = [1, 2, 3];

// A plain counter rather than `guidFor`: `@ember/object/internals` is not
// resolvable from a plugin bundle.
let dwellExampleId = 0;

export default class DwellExample extends Component {
  @tracked expanded = false;
  @tracked filedCount = 0;

  folderId = `styleguide-dwell-folder-${(dwellExampleId += 1)}`;

  @action
  canDwell() {
    return !this.expanded;
  }

  @action
  openFolder() {
    this.expanded = true;
  }

  @action
  maybeCloseFolder(event) {
    // Dropping into the folder keeps it open; any other end undoes the reveal.
    if (event.fired && !event.droppedHere) {
      this.expanded = false;
    }
  }

  @action
  fileChip() {
    this.filedCount += 1;
  }

  @action
  toggleFolder() {
    this.expanded = !this.expanded;
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <div
        class="styleguide-drag-and-drop__chip"
        {{dDragAndDropSource type="card"}}
      >{{i18n "styleguide.sections.drag_and_drop.drag_me"}}</div>

      <div
        class={{dConcatClass
          "styleguide-drag-and-drop__folder"
          (if this.expanded "--open")
        }}
        {{dDragAndDropTarget
          accepts="card"
          position="inside"
          onDrop=this.fileChip
        }}
        {{dDragDwell
          types="card"
          canDwell=this.canDwell
          onDwell=this.openFolder
          onDwellEnd=this.maybeCloseFolder
        }}
      >
        <DButton
          aria-controls={{if this.expanded this.folderId}}
          aria-expanded={{if this.expanded "true" "false"}}
          class="styleguide-drag-and-drop__folder-toggle"
          @action={{this.toggleFolder}}
          @translatedLabel={{if
            this.expanded
            (i18n "styleguide.sections.drag_and_drop.dwell_collapse")
            (i18n "styleguide.sections.drag_and_drop.dwell_expand")
          }}
        />

        {{#if this.expanded}}
          <div
            class="styleguide-drag-and-drop__folder-rows"
            id={{this.folderId}}
          >
            {{#each ROWS as |row|}}
              <div class="styleguide-drag-and-drop__folder-row">
                {{i18n "styleguide.sections.drag_and_drop.row" number=row}}
              </div>
            {{/each}}
          </div>
        {{/if}}

        {{! A drop can file the chip while the folder is collapsed. The count
        stays outside the reveal so that drop is visible at once. }}
        {{#if this.filedCount}}
          <div class="styleguide-drag-and-drop__folder-row">
            {{i18n
              "styleguide.sections.drag_and_drop.dwell_filed"
              count=this.filedCount
            }}
          </div>
        {{/if}}
      </div>
    </div>
  </template>
}
