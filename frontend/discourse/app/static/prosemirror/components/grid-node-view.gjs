import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
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
      contenteditable="false"
      role="group"
    >
      <button
        aria-label={{i18n "composer.grid_mode_grid"}}
        aria-pressed={{if (eq this.currentMode "grid") "true" "false"}}
        class={{dConcatClass
          "composer-image-gallery__mode-btn"
          (if (eq this.currentMode "grid") "is-active")
        }}
        data-mode="grid"
        title={{i18n
          "composer.grid_mode_title"
          mode=(i18n "composer.grid_mode_grid")
        }}
        type="button"
        {{on "click" (fn this.setMode "grid")}}
      >{{dIcon "table-cells"}}<span>{{i18n
            "composer.grid_mode_grid"
          }}</span></button>
      <button
        aria-label={{i18n "composer.grid_mode_carousel"}}
        aria-pressed={{if (eq this.currentMode "carousel") "true" "false"}}
        class={{dConcatClass
          "composer-image-gallery__mode-btn"
          (if (eq this.currentMode "carousel") "is-active")
        }}
        data-mode="carousel"
        title={{i18n
          "composer.grid_mode_title"
          mode=(i18n "composer.grid_mode_carousel")
        }}
        type="button"
        {{on "click" (fn this.setMode "carousel")}}
      >{{dIcon "image"}}<span>{{i18n
            "composer.grid_mode_carousel"
          }}</span></button>
    </div><button
      class="composer-image-grid__remove-btn"
      contenteditable="false"
      title={{i18n "composer.remove_grid"}}
      type="button"
      {{on "click" this.removeGrid}}
    ><span>{{i18n
          "composer.remove_grid"
        }}</span></button>{{~! strip whitespace ~}}
  </template>
}
