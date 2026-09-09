import { concat } from "@ember/helper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

/** Every indicator class a target can paint, shown without needing a drag. */
const POSITIONS = [
  { state: "--drag-above", label: "above" },
  { state: "--drag-below", label: "below" },
  { state: "--drag-left", label: "left" },
  { state: "--drag-right", label: "right" },
  { state: "--drag-inside", label: "inside" },
];

export default <template>
  <div class="styleguide-drag-and-drop__swatches">
    {{#each POSITIONS key="state" as |position|}}
      <div class="styleguide-drag-and-drop__swatch">
        <div
          class={{dConcatClass "styleguide-drag-and-drop__box" position.state}}
          data-drop-target
        >
          {{i18n
            (concat
              "styleguide.sections.drag_and_drop.positions." position.label
            )
          }}
        </div>
        <code>{{position.state}}</code>
      </div>
    {{/each}}
  </div>
</template>
