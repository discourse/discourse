import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { NodeSelection } from "prosemirror-state";
import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import { ToolbarBase } from "discourse/lib/composer/toolbar";
import { rovingButtonBar } from "discourse/lib/roving-button-bar";
import ImageAltTextInput from "./image-alt-text-input";

const MIN_SCALE = 50;
const MAX_SCALE = 100;
const SCALE_STEP = 25;
const MARGIN = 8;

class ImageToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    this.addButton({
      id: "image-alt-text",
      icon: "font",
      title: "composer.image_toolbar.alt_text",
      className: "composer-image-toolbar__alt-text",
      preventFocus: true,
      action: opts.editAltText,
      active: () => opts.isAltTextMenuOpen(),
    });

    this.addButton({
      id: "image-scale-down",
      icon: "magnifying-glass-minus",
      title: "composer.image_toolbar.zoom_out",
      className: "composer-image-toolbar__zoom-out",
      preventFocus: true,
      get disabled() {
        return !opts.canScaleDown();
      },
      action: opts.scaleDown,
    });

    this.addButton({
      id: "image-scale-up",
      icon: "magnifying-glass-plus",
      title: "composer.image_toolbar.zoom_in",
      className: "composer-image-toolbar__zoom-in",
      preventFocus: true,
      get disabled() {
        return !opts.canScaleUp();
      },
      action: opts.scaleUp,
    });

    this.addButton({
      id: "image-remove",
      icon: "trash-can",
      title: "composer.image_toolbar.remove",
      className: "composer-image-toolbar__trash",
      preventFocus: true,
      action: opts.removeImage,
    });
  }
}

export default class ImageNodeView extends Component {
  @service menu;

  @tracked imageToolbar = null;
  @tracked imageState = null;
  @tracked altMenuInstance = null;

  constructor() {
    super(...arguments);
    // Register this component instance with the nodeView
    this.args.data?.setComponentInstance?.(this);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.menuInstance?.destroy();
    this.altMenuInstance?.destroy();
  }

  stopEvent() {
    return this.menuInstance?.expanded;
  }

  #updateImageState() {
    const attrs = {
      node: this.node,
      scale: this.node.attrs["data-scale"] || 100,
    };

    if (!this.imageToolbar) {
      this.imageState = new TrackedObject(attrs);

      this.imageToolbar = new ImageToolbar({
        editAltText: this.editAltText.bind(this),
        scaleDown: this.scaleDown.bind(this),
        scaleUp: this.scaleUp.bind(this),
        removeImage: this.removeImage.bind(this),
        canScaleDown: () => this.imageState.scale > MIN_SCALE,
        canScaleUp: () => this.imageState.scale < MAX_SCALE,
        isAltTextMenuOpen: () => this.altMenuInstance?.expanded,
      });

      this.imageToolbar.rovingButtonBar = this.#rovingButtonBar.bind(this);
    } else {
      Object.assign(this.imageState, attrs);
    }
  }

  #rovingButtonBar(event) {
    if (event.key === "Tab" && !this.altMenuInstance?.expanded) {
      event.preventDefault();
      this.view.focus();
      return false;
    }

    // For arrow keys, prevent ProseMirror from handling them
    if (!rovingButtonBar(event)) {
      event.preventDefault();
      event.stopPropagation();

      return false;
    }

    return true;
  }

  @action
  async showMenu() {
    // Update state before showing menu
    this.#updateImageState();

    if (this.menuInstance) {
      this.menu.close(this.menuInstance);
    }

    this.menuInstance = await this.menu.show(this.nodeView.dom, {
      trigger: this.nodeView.dom.querySelector("img"),
      identifier: "composer-image-toolbar",
      component: ToolbarButtons,
      placement: "right-end",
      fallbackPlacements: ["left-end"],
      padding: MARGIN,
      data: this.imageToolbar,
      portalOutletElement: this.nodeView.dom,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      limitShift: {
        offset: ({ rects }) => ({ mainAxis: rects.floating.height + MARGIN }),
      },
      offset({ rects }) {
        return {
          mainAxis: -rects.reference.width + MARGIN,
          crossAxis: -rects.reference.height + MARGIN,
        };
      },
    });

    this.menu.show(this.menuInstance);
  }

  @action
  removeImage() {
    const pos = this.getPos();
    this.view.dispatch(this.view.state.tr.delete(pos, pos + 1));
  }

  @action
  async editAltText() {
    this.altMenuInstance?.close();

    const imgElement = this.nodeView.dom.querySelector("img");

    this.altMenuInstance = await this.menu.show(imgElement, {
      identifier: "composer-image-alt-text",
      component: ImageAltTextInput,
      placement: "right-end",
      fallbackPlacements: ["left-end"],
      padding: MARGIN,
      data: {
        alt: this.node.attrs.alt || "",
        onSave: (altText) => this.saveAltText(altText),
        onClose: () => this.view.focus(),
      },
      portalOutletElement: this.nodeView.dom,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      maxWidth: 0,
      offset: ({ rects }) => ({
        mainAxis: -rects.reference.width + MARGIN,
        crossAxis: -MARGIN,
      }),
      limitShift: {
        offset: ({ rects }) => ({ mainAxis: rects.floating.height }),
      },
    });
  }

  @action
  saveAltText(altText) {
    const pos = this.getPos();
    if (pos === undefined || pos === null) {
      return;
    }

    const tr = this.view.state.tr;
    const newAttrs = {
      ...this.node.attrs,
      alt: altText || null,
    };

    tr.setNodeMarkup(pos, null, newAttrs);
    tr.setSelection(NodeSelection.create(tr.doc, pos));
    this.view.dispatch(tr);

    this.view.focus();
  }

  @action
  scaleDown() {
    const currentScale = this.node.attrs["data-scale"] || 100;
    const newScale = Math.max(MIN_SCALE, currentScale - SCALE_STEP);
    this.scaleImage(newScale);
  }

  @action
  scaleUp() {
    const currentScale = this.node.attrs["data-scale"] || 100;
    const newScale = Math.min(MAX_SCALE, currentScale + SCALE_STEP);
    this.scaleImage(newScale);
  }

  @action
  scaleImage(scale) {
    const pos = this.getPos();
    const tr = this.view.state.tr;
    this.view.dispatch(
      tr
        .setNodeMarkup(pos, null, {
          ...this.node.attrs,
          "data-scale": scale,
        })
        .setSelection(NodeSelection.create(tr.doc, pos))
    );

    // Update reactive state immediately
    this.#updateImageState();
  }

  get node() {
    return this.args.data?.node;
  }

  get view() {
    return this.args.data?.view;
  }

  get getPos() {
    return this.args.data?.getPos;
  }

  get nodeView() {
    return this.args.data?.nodeView;
  }

  get imageAttrs() {
    const node = this.node;
    if (!node) {
      return {};
    }

    const { originalSrc, extras, ...attrs } = node.attrs;

    if (originalSrc) {
      attrs["data-orig-src"] = originalSrc;
    }
    if (extras === "thumbnail") {
      attrs["data-thumbnail"] = true;
    }

    if (node.attrs.width && node.attrs["data-scale"]) {
      attrs.width =
        (node.attrs.width * (node.attrs["data-scale"] || 100)) / 100;
    }
    if (node.attrs.height && node.attrs["data-scale"]) {
      attrs.height =
        (node.attrs.height * (node.attrs["data-scale"] || 100)) / 100;
    }

    return attrs;
  }

  selectNode() {
    this.nodeView.dom.classList.add("ProseMirror-selectednode");
    this.showMenu();
    this.editAltText();
  }

  deselectNode() {
    this.nodeView.dom.classList.remove("ProseMirror-selectednode");
    this.menuInstance?.close();
    this.altMenuInstance?.close();
  }

  <template>
    <img
      src={{this.imageAttrs.src}}
      alt={{this.imageAttrs.alt}}
      title={{this.imageAttrs.title}}
      width={{this.imageAttrs.width}}
      height={{this.imageAttrs.height}}
      data-orig-src={{this.imageAttrs.data-orig-src}}
      data-thumbnail={{this.imageAttrs.data-thumbnail}}
      data-scale={{this.imageAttrs.data-scale}}
    />
  </template>
}
