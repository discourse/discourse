import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { NodeSelection } from "prosemirror-state";
import ToolbarButtons from "discourse/components/composer/toolbar-buttons";
import { ToolbarBase } from "discourse/lib/composer/toolbar";
import { isRailsTesting, isTesting } from "discourse/lib/environment";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import ImageAltTextInput from "./image-alt-text-input";

const MIN_SCALE = 50;
const MAX_SCALE = 100;
const SCALE_STEP = 25;

const MENU_PADDING = 8;

const GRID_ADD_DIRECTION_END = -1;
const GRID_ADD_DIRECTION_START = 1;

class ImageToolbar extends ToolbarBase {
  constructor(opts = {}) {
    super(opts);

    const isInGrid = opts.isInGrid?.();

    if (!isInGrid) {
      this.addButton({
        id: "image-scale-down",
        icon: "magnifying-glass-minus",
        title: "composer.image_toolbar.zoom_out",
        className: "composer-image-toolbar__zoom-out",
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
        get disabled() {
          return !opts.canScaleUp();
        },
        action: opts.scaleUp,
        tabindex: 0,
      });
    }

    this.addButton({
      id: "image-remove",
      icon: "trash-can",
      title: "composer.image_toolbar.remove",
      className: "composer-image-toolbar__trash",
      action: opts.removeImage,
      tabindex: 0,
    });

    if (isInGrid) {
      this.addButton({
        id: "image-move-outside-grid",
        icon: "table-cells-minus",
        title: "composer.image_toolbar.move_outside_grid",
        className: "composer-image-toolbar__move-outside-grid",
        action: opts.moveOutsideGrid,
        tabindex: 0,
      });
    } else {
      this.addButton({
        id: "image-add-to-grid",
        icon: "table-cells-plus",
        title: "composer.image_toolbar.add_to_grid",
        className: "composer-image-toolbar__add-to-grid",
        action: opts.addToGrid,
        tabindex: 0,
      });
    }
  }
}

export default class ImageNodeView extends Component {
  @service menu;
  @service siteSettings;

  @tracked imageToolbar;
  @tracked menuInstance;
  @tracked altMenuInstance;
  @tracked imageLoaded = false;

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
      moveOutsideGrid: this.moveOutsideGrid.bind(this),
      addToGrid: this.addToGrid.bind(this),
      canScaleDown: () => {
        const scale = this.args.node.attrs.scale ?? 100;
        return scale > MIN_SCALE;
      },
      canScaleUp: () => {
        const scale = this.args.node.attrs.scale ?? 100;
        return scale < MAX_SCALE;
      },
      isAltTextMenuOpen: () => this.altMenuInstance?.expanded,
      isInGrid: () => this.isInGrid,
    });

    this.menuInstance = await this.menu.newInstance(this.args.dom, {
      identifier: "composer-image-toolbar",
      component: ToolbarButtons,
      placement: "top-start",
      fallbackPlacements: ["top-start"],
      padding: MENU_PADDING,
      data: this.imageToolbar,
      portalOutletElement: this.args.dom,
      closeOnClickOutside: false,
      closeOnEscape: false,
      closeOnScroll: false,
      trapTab: false,
      offset({ rects }) {
        return {
          mainAxis: -MENU_PADDING - rects.floating.height,
          crossAxis: MENU_PADDING,
        };
      },
      limitShift: {
        offset: ({ rects }) => {
          const inputHeight = this.altMenuInstance?.content?.offsetHeight || 0;

          return {
            crossAxis: Math.min(
              rects.floating.height + 2 * MENU_PADDING + inputHeight,
              rects.reference.height - MENU_PADDING
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
      padding: MENU_PADDING,
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
      offset: ({ rects }) => ({
        mainAxis: -MENU_PADDING - rects.floating.height,
        crossAxis: MENU_PADDING,
      }),
      limitShift: {
        offset: ({ rects }) => {
          const toolbarHeight = this.menuInstance?.content?.offsetHeight || 0;
          return {
            crossAxis: toolbarHeight + 2 * MENU_PADDING + rects.floating.height,
          };
        },
      },
    });

    await this.altMenuInstance.show();
  }

  @action
  saveAltText(altText, forceFocus) {
    const pos = this.args.getPos();
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
    const currentScale = this.args.node.attrs.scale ?? 100;
    const newScale = Math.max(MIN_SCALE, currentScale - SCALE_STEP);
    this.scaleImage(newScale);
  }

  @action
  scaleUp() {
    const currentScale = this.args.node.attrs.scale ?? 100;
    const newScale = Math.min(MAX_SCALE, currentScale + SCALE_STEP);
    this.scaleImage(newScale);
  }

  @action
  scaleImage(scale) {
    const pos = this.args.getPos();
    const tr = this.args.view.state.tr;

    if (!this.args.node.attrs.width || !this.args.node.attrs.height) {
      const dimensions = this.maxDimensions;
      if (dimensions) {
        tr.setNodeAttribute(pos, "width", dimensions.width);
        tr.setNodeAttribute(pos, "height", dimensions.height);
      }
    }

    tr.setNodeAttribute(pos, "scale", scale);
    tr.setSelection(NodeSelection.create(tr.doc, pos));
    this.args.view.dispatch(tr);
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

  get maxDimensions() {
    if (!this.imageLoaded) {
      return null;
    }

    const widthRatio =
      this.siteSettings.max_image_width / this.image.naturalWidth;
    const heightRatio =
      this.siteSettings.max_image_height / this.image.naturalHeight;

    const ratio = Math.min(widthRatio, heightRatio);

    return {
      width: Math.floor(this.image.naturalWidth * ratio),
      height: Math.floor(this.image.naturalHeight * ratio),
    };
  }

  get imageStyle() {
    const width = this.args.node.attrs.width ?? this.maxDimensions?.width;
    if (!width) {
      return null;
    }

    const scale = (this.args.node.attrs.scale ?? 100) / 100;

    return htmlSafe(`width: ${width * scale}px`);
  }

  get isInGrid() {
    const pos = this.args.getPos();
    const $pos = this.args.view.state.doc.resolve(pos);

    for (let depth = $pos.depth; depth >= 0; depth--) {
      if ($pos.node(depth).type.name === "grid") {
        return true;
      }
    }

    return false;
  }

  @action
  addToGrid() {
    const pos = this.args.getPos();
    const view = this.args.view;
    const { state } = view;
    const imageNode = this.args.node;

    const existingGrid = this.#findNearbyGrid(pos);

    if (existingGrid) {
      this.#addToExistingGrid(existingGrid, pos, imageNode, state, view);
    } else {
      const $pos = state.doc.resolve(pos);

      this.#createNewGrid(
        pos,
        imageNode,
        this.#isImageOnlyChildInParagraph($pos),
        state,
        view
      );
    }
  }

  #addToExistingGrid(existingGrid, pos, imageNode, state, view) {
    const { node: gridNode, pos: gridPos, direction } = existingGrid;
    const tr = state.tr;

    const paragraphWithImage = state.schema.nodes.paragraph.create(
      null,
      imageNode
    );
    let insertPos;

    if (direction === GRID_ADD_DIRECTION_END) {
      // Insert at the end of the grid
      insertPos = gridPos + gridNode.nodeSize - 2;
      tr.insert(insertPos, paragraphWithImage);
      const adjustedPos = pos + paragraphWithImage.nodeSize; // Account for the insertion
      tr.delete(adjustedPos, adjustedPos + 1);

      // if empty paragraph is left at adjustedPos, remove it explicitly
      const $adjustedPos = tr.doc.resolve(adjustedPos);
      if (
        $adjustedPos.parent.type.name === "paragraph" &&
        $adjustedPos.parent.content.size === 0
      ) {
        tr.delete(adjustedPos - 1, adjustedPos);
      }

      const newImagePos = insertPos + 1; // Insert position + paragraph boundary
      tr.setSelection(
        NodeSelection.create(tr.doc, newImagePos)
      ).scrollIntoView();
    } else {
      // Insert at the beginning of the grid
      tr.insert(gridPos, paragraphWithImage);
      tr.delete(pos, pos + 1);

      let imagePos = gridPos;

      const $pos = tr.doc.resolve(pos);
      if (
        $pos.parent.type.name === "paragraph" &&
        $pos.parent.content.size === 0
      ) {
        tr.delete(pos - 1, pos);
        imagePos -= 2;
      }

      tr.setSelection(NodeSelection.create(tr.doc, imagePos)).scrollIntoView();
    }

    view.dispatch(tr);
  }

  #createNewGrid(pos, imageNode, isOnlyChildInParagraph, state, view) {
    const tr = state.tr;
    const gridNode = state.schema.nodes.grid.create(
      null,
      state.schema.nodes.paragraph.create(null, imageNode)
    );

    let gridStartPos;
    if (isOnlyChildInParagraph) {
      tr.replaceWith(pos - 1, pos + 1, gridNode);
      gridStartPos = pos - 1;
    } else {
      tr.replaceWith(pos, pos + 1, gridNode);
      gridStartPos = pos;
    }

    // Select the image inside the new grid: grid + paragraph + image
    // Structure: grid(1) > paragraph(1) > image
    const imagePos = gridStartPos + 2; // Skip grid node boundary and paragraph node boundary
    tr.setSelection(NodeSelection.create(tr.doc, imagePos)).scrollIntoView();

    view.dispatch(tr);
  }

  /**
   * Check if the image at the resolved position is the only child in its paragraph.
   * Uses position-based API for reliable detection instead of direct node comparison.
   *
   * @param {import("prosemirror-model").ResolvedPos} $pos - The resolved position of the image
   * @returns {boolean} True if the image is the only child in a paragraph
   */
  #isImageOnlyChildInParagraph($pos) {
    const parent = $pos.parent;

    // Must be in a paragraph
    if (parent.type.name !== "paragraph") {
      return false;
    }

    // Paragraph must have exactly one child
    if (parent.childCount !== 1) {
      return false;
    }

    // The single child must be an image at the current position
    const index = $pos.index();
    const childAtIndex = parent.child(index);

    return childAtIndex.type.name === "image";
  }

  #findNearbyGrid(pos) {
    const { state } = this.args.view;
    const $pos = state.doc.resolve(pos);

    // Find the block containing the image (paragraph)
    let blockDepth = $pos.depth;
    while (blockDepth > 0 && $pos.node(blockDepth).type.name !== "paragraph") {
      blockDepth--;
    }

    if (blockDepth === 0) {
      return null;
    }

    const blockPos = $pos.start(blockDepth);
    const blockNode = $pos.node(blockDepth);
    const blockParent = $pos.node(blockDepth - 1);
    const blockIndex = $pos.index(blockDepth - 1);

    // Check if left sibling is a grid
    if (blockIndex > 0) {
      const leftNode = blockParent.child(blockIndex - 1);
      if (leftNode.type.name === "grid") {
        return {
          node: leftNode,
          pos: blockPos - leftNode.nodeSize,
          direction: GRID_ADD_DIRECTION_END,
        };
      }
    }

    // Check if right sibling is a grid
    if (blockIndex < blockParent.childCount - 1) {
      const rightNode = blockParent.child(blockIndex + 1);
      if (rightNode.type.name === "grid") {
        return {
          node: rightNode,
          pos: blockPos + blockNode.nodeSize,
          direction: GRID_ADD_DIRECTION_START,
        };
      }
    }

    return null;
  }

  @action
  moveOutsideGrid() {
    if (!this.isInGrid) {
      return;
    }

    const pos = this.args.getPos();
    const view = this.args.view;
    const { state } = view;
    const { tr } = state;
    const imageNode = this.args.node;

    const $pos = state.doc.resolve(pos);
    let gridDepth = null;
    let gridPos = null;

    for (let depth = $pos.depth; depth >= 0; depth--) {
      if ($pos.node(depth).type.name === "grid") {
        gridDepth = depth;
        gridPos = $pos.start(depth);
        break;
      }
    }

    if (gridDepth === null) {
      return;
    }

    const gridNode = $pos.node(gridDepth);

    const willGridBeEmpty =
      gridNode.childCount === 1 &&
      gridNode.firstChild.type.name === "paragraph" &&
      gridNode.firstChild.content.size === 1 &&
      gridNode.firstChild.firstChild.type.name === "image";

    const gridEndPos = gridPos + gridNode.nodeSize - 1;
    const paragraphWithImage = state.schema.nodes.paragraph.create(
      null,
      imageNode
    );

    if (willGridBeEmpty) {
      tr.replaceWith(
        gridPos - 1,
        gridPos + gridNode.nodeSize,
        paragraphWithImage
      );
      tr.setSelection(NodeSelection.create(tr.doc, gridPos)).scrollIntoView();
    } else {
      tr.delete(pos - 1, pos + 1);

      const adjustedGridEndPos = tr.mapping.map(gridEndPos);
      tr.insert(adjustedGridEndPos, paragraphWithImage);

      const newImagePos = adjustedGridEndPos + 1; // Insert position + paragraph boundary
      tr.setSelection(
        NodeSelection.create(tr.doc, newImagePos)
      ).scrollIntoView();
    }

    view.dispatch(tr);
  }

  @action
  updateImageLoaded() {
    this.imageLoaded = true;
  }

  @action
  async handleImageClick(event) {
    if (this.image.classList.contains("ProseMirror-selectednode")) {
      event?.preventDefault();
      event?.stopPropagation();

      await openLightbox(this.args.view.dom, this.image);

      const pos = this.args.getPos();
      if (pos !== null && pos >= 0) {
        const tr = this.args.view.state.tr.setSelection(
          NodeSelection.create(this.args.view.state.doc, pos)
        );
        this.args.view.dispatch(tr);
      }
    }
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
      role="button"
      {{didInsert this.setupImage}}
      {{on "load" this.updateImageLoaded}}
      {{on "click" this.handleImageClick}}
    />
  </template>
}

async function openLightbox(editorElement, currentImage) {
  const allImages = [
    ...editorElement.querySelectorAll(".composer-image-node img"),
  ];
  const currentIndex = allImages.indexOf(currentImage);

  const dataSource = allImages.map((img) => {
    return {
      src: img.src,
      msrc: img.currentSrc || img.src,
      width: img.naturalWidth || 800,
      height: img.naturalHeight || 600,
      alt: img.alt || "",
      element: img,
      thumbCropped: true,
    };
  });

  const { default: PhotoSwipeLightbox } = await import("photoswipe/lightbox");
  const isTestEnv = isTesting() || isRailsTesting();

  const lightbox = new PhotoSwipeLightbox({
    dataSource,
    showHideAnimationType: isTestEnv ? "none" : "zoom",
    closeTitle: i18n("lightbox.close"),
    zoomTitle: i18n("lightbox.zoom"),
    arrowPrevTitle: i18n("lightbox.previous"),
    arrowNextTitle: i18n("lightbox.next"),
    pswpModule: () => import("photoswipe"),
    tapAction: (pt, e) => {
      if (e.target.classList.contains("pswp__img")) {
        lightbox.pswp?.element?.classList.toggle("pswp--ui-visible");
      } else {
        lightbox.pswp?.close();
      }
    },
  });

  lightbox.on("uiRegister", function () {
    lightbox.pswp.ui.registerElement({
      name: "caption",
      order: 11,
      isButton: false,
      appendTo: "root",
      html: "",
      onInit: (caption, pswp) => {
        pswp.on("change", () => {
          const slideData = pswp.getItemData(pswp.currIndex);
          const alt = slideData?.alt;
          if (alt) {
            caption.innerHTML = `<div class='pswp__caption-title'>${alt}</div>`;
          } else {
            caption.innerHTML = "";
          }
        });
      },
    });
  });

  return new Promise((resolve) => {
    lightbox.addFilter("thumbEl", (thumbEl, itemData) => itemData.element);
    lightbox.on("close", resolve);
    lightbox.on("closingAnimationEnd", () => lightbox.destroy());

    lightbox.init();
    lightbox.loadAndOpen(currentIndex);
  });
}
