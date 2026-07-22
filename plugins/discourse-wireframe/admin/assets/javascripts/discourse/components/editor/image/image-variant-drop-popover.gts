import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import { i18n } from "discourse-i18n";
import type { ImageUploadPayload } from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-image-upload";

export type ImageVariantDropPopoverData = {
  /** Composite key of the block whose image is being edited. */
  blockKey: string;
  /** Name of the image argument being edited. */
  argName: string;
  /** Whether the image already has a dark variant. */
  hasDarkVariant: boolean;
  /** Handles a completed dark-variant upload. */
  onDarkUpload: (
    /** Successful image upload payload. */
    upload: ImageUploadPayload
  ) => void;
  /** Handles the pointer entering the popover drop target. */
  onPopoverEnter: () => void;
  /** Handles the pointer leaving the popover drop target. */
  onPopoverLeave: () => void;
};

interface ImageVariantDropPopoverSignature {
  /** FloatKit data driving the dark-variant drop target. */
  Args: {
    /** Block, argument, upload, and drag callbacks. */
    data: ImageVariantDropPopoverData;
  };
}

/**
 * FloatKit menu content for adding / replacing the dark variant of
 * an image arg via drag-and-drop.
 *
 * Mounted by `menu.show(overlayEl, { component: ImageVariantDropPopover,
 * data })` from the image overlay when the user starts dragging a
 * file over the image. The popover hosts its own `UppyUpload`
 * instance with its own DropTarget — dropping a file onto the
 * popover triggers the dark-variant upload pipeline, decoupled
 * from the main image overlay's light-variant pipeline.
 *
 * Drag visuals are wired through `{{dDragAndDropExternalTarget}}`
 * (the ui-kit PDND wrapper). The popover and the overlay both
 * register as PDND external drop targets so PDND's lifecycle
 * dispatches enter/leave transitions between them atomically — and
 * fires `onDragLeave` on whichever target was deepest when the
 * drag ends, even if the user cancels (Esc, off-window release).
 *
 * @data shape (injected by FloatKit as `@data`):
 *   - blockKey {string}
 *   - argName  {string}
 *   - hasDarkVariant {boolean} — drives the label text
 *   - onDarkUpload {(upload: Object) => void} — called with the
 *     UppyUpload `uploadDone` payload; the overlay's owner
 *     re-uses it to write to `entry.args[argName].dark`
 *   - onPopoverEnter {() => void} — called when PDND reports the
 *     popover became the deepest drop target.
 *   - onPopoverLeave {() => void} — called when PDND reports the
 *     popover left the drop-target stack (cursor moved elsewhere
 *     or the drag ended).
 */
export default class ImageVariantDropPopover extends Component<ImageVariantDropPopoverSignature> {
  /** Whether an external file drag is over the popover. */
  @tracked isDragOver: boolean = false;

  /** The drop-target element ref. Set on insert. */
  #dropEl: HTMLElement | null = null;

  /** Per-popover UppyUpload. */
  #uppy: UppyUpload | null = null;

  /** Label for adding or replacing the dark variant. */
  get label(): string {
    return this.args.data.hasDarkVariant
      ? i18n("wireframe.canvas.image_drop_replace_dark")
      : i18n("wireframe.canvas.image_drop_add_dark");
  }

  /**
   * Creates the popover's external-drop upload pipeline.
   *
   * @param element - Mounted popover drop target.
   */
  @action
  setup(element: HTMLElement): void {
    this.#dropEl = element;
    this.#uppy = new UppyUpload(getOwner(this), {
      id: `wireframe-img-dark-${this.args.data.blockKey}-${this.args.data.argName}-${Date.now()}`,
      type: "composer",
      validateUploadedFilesOptions: { imagesOnly: true },
      uploadDropTargetOptions: () => ({ target: this.#dropEl }),
      uploadDone: (upload: ImageUploadPayload) => {
        this.args.data.onDarkUpload(upload);
      },
    });
    // TODO(devxp-typescript-pending): call `setup()` with no argument once
    // UppyUpload marks its optional file-input parameter accordingly.
    this.#uppy.setup(undefined);
  }

  /** Tears down the popover upload pipeline. */
  @action
  teardown(): void {
    this.#uppy?.teardown();
  }

  /** Marks the popover as the active external drop target. */
  @action
  onExternalDragEnter(): void {
    this.isDragOver = true;
    this.args.data.onPopoverEnter();
  }

  /** Clears the popover's external drag claim. */
  @action
  onExternalDragLeave(): void {
    this.isDragOver = false;
    this.args.data.onPopoverLeave();
  }

  /** Clears drag-over styling after a drop. */
  @action
  onExternalDrop(): void {
    this.isDragOver = false;
  }

  <template>
    <div
      class="wireframe-image-variant-drop-popover
        {{if
          this.isDragOver
          'wireframe-image-variant-drop-popover--drag-over'
        }}"
      {{didInsert this.setup}}
      {{willDestroy this.teardown}}
      {{dDragAndDropExternalTarget
        accepts="files"
        indicator=false
        onDragEnter=this.onExternalDragEnter
        onDragLeave=this.onExternalDragLeave
        onDrop=this.onExternalDrop
      }}
    >
      {{dIcon "moon"}}
      <span>{{this.label}}</span>
    </div>
  </template>
}
