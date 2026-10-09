import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import dResizeEdge from "discourse/ui-kit/modifiers/d-resize-edge";
import { i18n } from "discourse-i18n";

const MAX = 320;
const MIN = 80;

export default class EdgeExample extends Component {
  @tracked width = 160;

  get paneStyle() {
    return trustHTML(`width: ${this.width}px;`);
  }

  @action
  onResize(size) {
    this.width = size;
  }

  <template>
    <div class="styleguide-drag-and-drop__panes">
      <div class="styleguide-drag-and-drop__pane" style={{this.paneStyle}}>
        {{i18n "styleguide.sections.drag_and_drop.left_pane"}}
      </div>

      {{! Everything the separator component would have supplied is spelled out
      here, because the modifier owns the interaction and nothing else. }}
      <div
        aria-label={{i18n "styleguide.sections.drag_and_drop.edge_label"}}
        aria-orientation="vertical"
        aria-valuemax={{MAX}}
        aria-valuemin={{MIN}}
        aria-valuenow={{this.width}}
        class="styleguide-drag-and-drop__divider"
        role="separator"
        tabindex="0"
        {{dResizeEdge
          value=this.width
          min=MIN
          max=MAX
          axis="horizontal"
          bodyClass="d-resizing-ew"
          onResize=this.onResize
        }}
      ></div>

      <div class="styleguide-drag-and-drop__pane --grow">
        {{i18n "styleguide.sections.drag_and_drop.right_pane"}}
      </div>
    </div>
  </template>
}
