// @ts-check
import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Context-sensitive editor for the `viewport` condition.
 *
 * Quick-pick chips for the three common ranges (mobile only, tablet+,
 * desktop+) cover ~95% of authoring needs. A touch-state segmented
 * control sits below. Advanced authors who need exact breakpoint pairs
 * can edit via the Raw JSON tab.
 */
const RANGES = [
  {
    id: "any",
    min: undefined,
    max: undefined,
    label: "viewport_any",
    icon: "expand",
  },
  {
    id: "mobile",
    min: undefined,
    max: "sm",
    label: "viewport_mobile",
    icon: "mobile-screen",
  },
  {
    id: "tablet-up",
    min: "md",
    max: undefined,
    label: "viewport_tablet_up",
    icon: "tablet-screen-button",
  },
  {
    id: "desktop-up",
    min: "lg",
    max: undefined,
    label: "viewport_desktop_up",
    icon: "desktop",
  },
];

const TOUCH_MODES = [
  { id: "any", label: "touch_any" },
  { id: "touch", label: "touch_touch" },
  { id: "non-touch", label: "touch_non_touch" },
];

export default class ViewportConditionEditor extends Component {
  get currentRange() {
    const { min, max } = this.args.leaf;
    if (min === undefined && max === "sm") {
      return "mobile";
    }
    if (min === "md" && max === undefined) {
      return "tablet-up";
    }
    if (min === "lg" && max === undefined) {
      return "desktop-up";
    }
    if (min === undefined && max === undefined) {
      return "any";
    }
    return null;
  }

  get touchMode() {
    if (this.args.leaf.touch === true) {
      return "touch";
    }
    if (this.args.leaf.touch === false) {
      return "non-touch";
    }
    return "any";
  }

  patch(patch) {
    const next = { ...this.args.leaf };
    for (const [k, v] of Object.entries(patch)) {
      if (v === undefined) {
        delete next[k];
      } else {
        next[k] = v;
      }
    }
    this.args.onChange(next);
  }

  @action
  pickRange(rangeId) {
    const range = RANGES.find((r) => r.id === rangeId);
    if (!range) {
      return;
    }
    this.patch({ min: range.min, max: range.max });
  }

  @action
  setTouch(mode) {
    if (mode === "any") {
      this.patch({ touch: undefined });
    } else if (mode === "touch") {
      this.patch({ touch: true });
    } else {
      this.patch({ touch: false });
    }
  }

  <template>
    <div
      class="visual-editor-condition-editor visual-editor-condition-editor--viewport"
    >
      <div class="visual-editor-condition-editor__field">
        <span class="visual-editor-condition-editor__legend">
          {{i18n
            "visual_editor.inspector.conditions.viewport_editor.size_legend"
          }}
        </span>
        <div class="visual-editor-condition-editor__viewport-chips">
          {{#each RANGES as |range|}}
            <button
              type="button"
              class={{dConcatClass
                "visual-editor-condition-editor__viewport-chip"
                (if (eq this.currentRange range.id) "--active")
              }}
              {{on "click" (fn this.pickRange range.id)}}
            >
              {{dIcon range.icon}}
              <span>{{i18n
                  (concat
                    "visual_editor.inspector.conditions.viewport_editor."
                    range.label
                  )
                }}</span>
            </button>
          {{/each}}
        </div>
      </div>

      <div class="visual-editor-condition-editor__field">
        <span class="visual-editor-condition-editor__legend">
          {{i18n
            "visual_editor.inspector.conditions.viewport_editor.touch_legend"
          }}
        </span>
        <div
          class="visual-editor-condition-editor__segmented"
          role="radiogroup"
        >
          {{#each TOUCH_MODES as |mode|}}
            <button
              type="button"
              class={{dConcatClass
                "visual-editor-condition-editor__segment"
                (if (eq this.touchMode mode.id) "--active")
              }}
              role="radio"
              aria-checked={{eq this.touchMode mode.id}}
              {{on "click" (fn this.setTouch mode.id)}}
            >
              {{i18n
                (concat
                  "visual_editor.inspector.conditions.viewport_editor."
                  mode.label
                )
              }}
            </button>
          {{/each}}
        </div>
      </div>
    </div>
  </template>
}
