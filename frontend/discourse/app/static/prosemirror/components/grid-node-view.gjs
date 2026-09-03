import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const MENU_PADDING = 8;
const MODE_MENU_IDENTIFIER = "composer-image-grid-mode";
const REMOVE_MENU_IDENTIFIER = "composer-image-grid-remove";

const GridModeButtons = <template>
  <div
    class="composer-image-gallery__mode-buttons"
    role="group"
    contenteditable="false"
  >
    <button
      type="button"
      class={{dConcatClass
        "composer-image-gallery__mode-btn"
        (if (eq @data.currentMode "grid") "is-active")
      }}
      data-mode="grid"
      aria-label={{i18n "composer.grid_mode_grid"}}
      title={{i18n
        "composer.grid_mode_title"
        mode=(i18n "composer.grid_mode_grid")
      }}
      aria-pressed={{if (eq @data.currentMode "grid") "true" "false"}}
      {{on "click" (fn @data.setMode "grid")}}
    >{{dIcon "table-cells"}}<span>{{i18n
          "composer.grid_mode_grid"
        }}</span></button>
    <button
      type="button"
      class={{dConcatClass
        "composer-image-gallery__mode-btn"
        (if (eq @data.currentMode "carousel") "is-active")
      }}
      data-mode="carousel"
      aria-label={{i18n "composer.grid_mode_carousel"}}
      title={{i18n
        "composer.grid_mode_title"
        mode=(i18n "composer.grid_mode_carousel")
      }}
      aria-pressed={{if (eq @data.currentMode "carousel") "true" "false"}}
      {{on "click" (fn @data.setMode "carousel")}}
    >{{dIcon "image"}}<span>{{i18n
          "composer.grid_mode_carousel"
        }}</span></button>
  </div>
</template>;

const RemoveGridButton = <template>
  <button
    type="button"
    class="composer-image-grid__remove-btn"
    title={{i18n "composer.remove_grid"}}
    contenteditable="false"
    {{on "click" @data.removeGrid}}
  ><span>{{i18n "composer.remove_grid"}}</span></button>
</template>;

export default class GridNodeView extends Component {
  @service menu;

  #modeMenuInstance;
  #removeMenuInstance;

  // Note: contentDOM is appended to dom in GlimmerNodeView constructor
  // and is a sibling of the Glimmer-rendered content

  constructor() {
    super(...arguments);
    this.args.dom?.classList.add("composer-image-grid");
    this.args.contentDOM?.classList.add("composer-image-grid__content");
    this.args.onSetup?.(this);
    this.#showMenus(guidFor(this));
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#modeMenuInstance?.destroy();
    this.#removeMenuInstance?.destroy();
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

  stopEvent(event) {
    return !!(
      this.#modeMenuInstance?.content?.contains(event.target) ||
      this.#removeMenuInstance?.content?.contains(event.target)
    );
  }

  selectNode() {
    this.args.dom.classList.add("ProseMirror-selectednode");
  }

  deselectNode() {
    this.args.dom.classList.remove("ProseMirror-selectednode");
  }

  async #showMenus(menuId) {
    this.#modeMenuInstance = this.menu.newInstance(this.args.dom, {
      identifier: `${MODE_MENU_IDENTIFIER}-${menuId}`,
      component: GridModeButtons,
      contentRole: "none",
      placement: "top-end",
      fallbackPlacements: ["top-end"],
      padding: MENU_PADDING,
      data: this,
      portalOutletElement: this.args.dom,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      trapTab: false,
      offset({ rects }) {
        return {
          mainAxis: -MENU_PADDING - rects.floating.height,
          crossAxis: -MENU_PADDING,
        };
      },
      onPositioned: () => this.#updateControlsMinBlockSize(),
      limitShift: {
        offset: ({ rects }) => {
          const removeButtonHeight =
            this.#removeMenuInstance?.content?.offsetHeight || 0;

          return {
            crossAxis: Math.min(
              rects.floating.height + 2 * MENU_PADDING + removeButtonHeight,
              rects.reference.height - MENU_PADDING
            ),
          };
        },
      },
    });

    this.#removeMenuInstance = this.menu.newInstance(this.args.dom, {
      identifier: `${REMOVE_MENU_IDENTIFIER}-${menuId}`,
      component: RemoveGridButton,
      contentRole: "none",
      placement: "bottom-end",
      fallbackPlacements: ["bottom-end"],
      padding: MENU_PADDING,
      data: this,
      portalOutletElement: this.args.dom,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      trapTab: false,
      offset({ rects }) {
        return {
          mainAxis: -MENU_PADDING - rects.floating.height,
          crossAxis: -MENU_PADDING,
        };
      },
      onPositioned: () => this.#updateControlsMinBlockSize(),
      limitShift: {
        offset: ({ rects }) => {
          const modeButtonsHeight =
            this.#modeMenuInstance?.content?.offsetHeight || 0;

          return {
            crossAxis:
              modeButtonsHeight + 2 * MENU_PADDING + rects.floating.height,
          };
        },
      },
    });

    await Promise.all([
      this.#modeMenuInstance.show(),
      this.#removeMenuInstance.show(),
    ]);
    this.#updateControlsMinBlockSize();
  }

  #updateControlsMinBlockSize() {
    const modeButtonsHeight =
      this.#modeMenuInstance?.content?.offsetHeight || 0;
    const removeButtonHeight =
      this.#removeMenuInstance?.content?.offsetHeight || 0;

    if (!modeButtonsHeight || !removeButtonHeight) {
      return;
    }

    const controlsHeight =
      modeButtonsHeight + removeButtonHeight + 3 * MENU_PADDING;
    const minBlockSize = `${controlsHeight}px`;

    if (
      this.args.dom.style.getPropertyValue(
        "--composer-image-grid-controls-min-block-size"
      ) !== minBlockSize
    ) {
      this.args.dom.style.setProperty(
        "--composer-image-grid-controls-min-block-size",
        minBlockSize
      );
    }
  }
}
