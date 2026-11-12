import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DResizeSeparator from "discourse/ui-kit/d-resize-separator";
import { i18n } from "discourse-i18n";

const MIN = 80;
const MAX = 320;

export default class SeparatorExample extends Component {
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

      <DResizeSeparator
        class="styleguide-drag-and-drop__divider"
        @axis="horizontal"
        @label={{i18n "styleguide.sections.drag_and_drop.separator_label"}}
        @max={{MAX}}
        @min={{MIN}}
        @onResize={{this.onResize}}
        @value={{this.width}}
      />

      <div class="styleguide-drag-and-drop__pane --grow">
        {{i18n "styleguide.sections.drag_and_drop.right_pane"}}
      </div>
    </div>
  </template>
}
