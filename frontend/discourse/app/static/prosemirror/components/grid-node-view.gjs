import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class GridNodeView extends Component {
  // Note: contentDOM is appended to dom in GlimmerNodeView constructor
  // and is a sibling of the Glimmer-rendered content

  constructor() {
    super(...arguments);
    this.args.dom?.classList.add("composer-image-grid");
    this.args.onSetup?.(this);
  }

  get currentMode() {
    return this.args.node.attrs.mode;
  }

  @action
  setMode(mode, event) {
    event.preventDefault();
    const pos = this.args.getPos();
    this.args.view.dispatch(
      this.args.view.state.tr.setNodeMarkup(pos, null, {
        ...this.args.node.attrs,
        mode,
      })
    );
  }

  @action
  removeGrid(event) {
    event.preventDefault();
    event.stopPropagation();
    const pos = this.args.getPos();
    const node = this.args.view.state.doc.nodeAt(pos);
    const tr = this.args.view.state.tr;
    tr.replaceWith(pos, pos + node.nodeSize, node.content);
    this.args.view.dispatch(tr);
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  <template>
    {{~! strip whitespace ~}}<div
      class="composer-image-gallery__mode-buttons"
      role="group"
      contenteditable="false"
    >
      <button
        type="button"
        class={{concatClass
          "composer-image-gallery__mode-btn"
          (if (eq this.currentMode "grid") "is-active")
        }}
        data-mode="grid"
        aria-label={{i18n "composer.grid_mode_grid"}}
        title={{i18n
          "composer.grid_mode_title"
          mode=(i18n "composer.grid_mode_grid")
        }}
        aria-pressed={{if (eq this.currentMode "grid") "true" "false"}}
        {{on "click" (fn this.setMode "grid")}}
      >{{icon "table-cells"}}<span>{{i18n
            "composer.grid_mode_grid"
          }}</span></button>
      <button
        type="button"
        class={{concatClass
          "composer-image-gallery__mode-btn"
          (if (eq this.currentMode "carousel") "is-active")
        }}
        data-mode="carousel"
        aria-label={{i18n "composer.grid_mode_carousel"}}
        title={{i18n
          "composer.grid_mode_title"
          mode=(i18n "composer.grid_mode_carousel")
        }}
        aria-pressed={{if (eq this.currentMode "carousel") "true" "false"}}
        {{on "click" (fn this.setMode "carousel")}}
      >{{icon "image"}}<span>{{i18n
            "composer.grid_mode_carousel"
          }}</span></button>
    </div><button
      type="button"
      class="composer-image-grid__remove-btn"
      title={{i18n "composer.remove_grid"}}
      contenteditable="false"
      {{on "click" this.removeGrid}}
    ><span>{{i18n
          "composer.remove_grid"
        }}</span></button>{{~! strip whitespace ~}}
  </template>
}
