import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { NodeSelection } from "prosemirror-state";
import { eq } from "truth-helpers";
import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import { ToolbarBase } from "discourse/lib/composer/toolbar";
import ImageAltTextInput from "./image-alt-text-input";

const MIN_SCALE = 50;
const MAX_SCALE = 100;
const SCALE_STEP = 25;

const MARGIN = 8;

class ImageToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

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
      tabindex: 0,
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
      tabindex: 0,
    });

    this.addButton({
      id: "image-remove",
      icon: "trash-can",
      title: "composer.image_toolbar.remove",
      className: "composer-image-toolbar__trash",
      preventFocus: true,
      action: opts.removeImage,
      tabindex: 0,
    });
  }
}

export default class ImageNodeView extends Component {
  @service menu;

  @tracked imageToolbar;
  @tracked menuInstance;
  @tracked altMenuInstance;

  constructor() {
    super(...arguments);

    this.args.onSetup?.(this);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.closeMenus();
  }

  stopEvent(event) {
    if (["dragover", "dragend", "drop", "dragleave"].includes(event.type)) {
      return false;
    }

    return (
      this.menuInstance?.content?.contains(event.target) ||
      this.altMenuInstance?.content?.contains(event.target)
    );
  }

  @action
  async showToolbar() {
    this.imageToolbar ??= new ImageToolbar({
      scaleDown: this.scaleDown.bind(this),
      scaleUp: this.scaleUp.bind(this),
      removeImage: this.removeImage.bind(this),
      canScaleDown: () =>
        !this.args.node.attrs.scale || this.args.node.attrs.scale > MIN_SCALE,
      canScaleUp: () =>
        this.args.node.attrs.scale && this.args.node.attrs.scale < MAX_SCALE,
      isAltTextMenuOpen: () => this.altMenuInstance?.expanded,
    });

    this.menuInstance = await this.menu.newInstance(this.args.dom, {
      identifier: "composer-image-toolbar",
      component: ToolbarButtons,
      placement: "top-start",
      fallbackPlacements: ["top-start"],
      padding: MARGIN,
      data: this.imageToolbar,
      portalOutletElement: this.args.dom,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      trapTab: false,
      offset({ rects }) {
        return {
          mainAxis: -MARGIN - rects.floating.height,
          crossAxis: MARGIN,
        };
      },
      limitShift: {
        offset: ({ rects }) => {
          const inputHeight = this.altMenuInstance?.content?.offsetHeight || 0;

          return {
            crossAxis: Math.min(
              rects.floating.height + 2 * MARGIN + inputHeight,
              rects.reference.height - MARGIN
            ),
          };
        },
      },
    });

    await this.menuInstance.show();
  }

  @action
  removeImage() {
    const pos = this.args.getPos();
    this.args.view.dispatch(this.args.view.state.tr.delete(pos, pos + 1));
  }

  @action
  async showAltText() {
    this.altMenuInstance = await this.menu.newInstance(this.args.dom, {
      identifier: "composer-image-alt-text",
      component: ImageAltTextInput,
      placement: "bottom-start",
      fallbackPlacements: ["bottom-start"],
      padding: MARGIN,
      data: {
        alt: this.args.node.attrs.alt,
        onSave: this.saveAltText,
        onClose: () => this.args.view.focus(),
        view: this.args.view,
      },
      portalOutletElement: this.args.dom,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      trapTab: false,
      maxWidth: 0,
      offset: ({ rects }) => ({
        mainAxis: -MARGIN - rects.floating.height,
        crossAxis: MARGIN,
      }),
      limitShift: {
        offset: ({ rects }) => {
          const toolbarHeight = this.menuInstance?.content?.offsetHeight || 0;
          return {
            crossAxis: toolbarHeight + 2 * MARGIN + rects.floating.height,
          };
        },
      },
    });

    await this.altMenuInstance.show();
  }

  @action
  saveAltText(altText, forceFocus) {
    const pos = this.args.getPos();
    if (pos === undefined || pos === null) {
      return;
    }

    const tr = this.args.view.state.tr;
    const newAttrs = {
      ...this.args.node.attrs,
      alt: altText || null,
    };

    tr.setNodeMarkup(pos, null, newAttrs);
    tr.setSelection(NodeSelection.create(tr.doc, pos));
    this.args.view.dispatch(tr);

    if (forceFocus) {
      this.args.view.focus();
    }
  }

  @action
  setupImage(element) {
    this.image = element;
  }

  @action
  scaleDown() {
    const currentScale = this.args.node.attrs.scale || 100;
    const newScale = Math.max(MIN_SCALE, currentScale - SCALE_STEP);
    this.scaleImage(newScale);
  }

  @action
  scaleUp() {
    const currentScale = this.args.node.attrs.scale || 100;
    const newScale = Math.min(MAX_SCALE, currentScale + SCALE_STEP);
    this.scaleImage(newScale);
  }

  @action
  scaleImage(scale) {
    const pos = this.args.getPos();
    const tr = this.args.view.state.tr;
    this.args.view.dispatch(
      tr
        .setNodeMarkup(pos, null, {
          ...this.args.node.attrs,
          scale,
        })
        .setSelection(NodeSelection.create(tr.doc, pos))
    );
  }

  selectNode() {
    this.image.classList.add("ProseMirror-selectednode");

    this.showToolbar();
    this.showAltText();
  }

  deselectNode() {
    this.image.classList.remove("ProseMirror-selectednode");

    this.closeMenus();
  }

  closeMenus() {
    this.menuInstance?.close();
    this.menuInstance = null;
    this.altMenuInstance?.close();
    this.altMenuInstance = null;
  }

  get imageStyle() {
    if (
      !this.args.node.attrs.scale ||
      this.args.node.attrs.scale === 100 ||
      !this.args.node.attrs.width ||
      !this.args.node.attrs.height
    ) {
      return null;
    }

    const scale = this.args.node.attrs.scale / 100;

    return htmlSafe(
      `width: ${this.args.node.attrs.width * scale}px; height: ${
        this.args.node.attrs.height * scale
      }px;`
    );
  }

  <template>
    <img
      src={{@node.attrs.src}}
      alt={{@node.attrs.alt}}
      title={{@node.attrs.title}}
      width={{@node.attrs.width}}
      height={{@node.attrs.height}}
      data-orig-src={{@node.attrs.originalSrc}}
      data-scale={{@node.attrs.scale}}
      data-thumbnail={{if (eq @node.attrs.extras "thumbnail") "true"}}
      style={{this.imageStyle}}
      {{didInsert this.setupImage}}
    />
  </template>
}
