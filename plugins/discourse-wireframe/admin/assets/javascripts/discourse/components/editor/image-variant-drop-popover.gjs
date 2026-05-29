// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * FloatKit menu content for adding / replacing the dark variant of
 * an image arg via drag-and-drop.
 *
 * Mounted by `menu.show(overlayEl, { component: ImageVariantDropPopover,
 * data })` from the image overlay when the user has been dragging
 * over the image for ~250ms. The popover hosts its own
 * `UppyUpload` instance with its own DropTarget — dropping a file
 * onto the popover triggers the dark-variant upload pipeline,
 * decoupled from the main image overlay's light-variant pipeline.
 *
 * @data shape (injected by FloatKit as `@data`):
 *   - blockKey {string}
 *   - argName  {string}
 *   - hasDarkVariant {boolean} — drives the label text
 *   - onDarkUpload {(upload: Object) => void} — called with the
 *     UppyUpload `uploadDone` payload; the overlay's owner
 *     re-uses it to write to `entry.args[argName].dark`
 *   - onPopoverEnter {() => void} — called on dragenter so the
 *     overlay can cancel FloatKit's hover-close timer
 *   - onPopoverLeave {() => void} — called on dragleave so the
 *     overlay can schedule FloatKit's hover-close
 */
export default class ImageVariantDropPopover extends Component {
  @tracked isDragOver = false;

  /** The drop-target element ref. Set on insert. */
  #dropEl = null;

  /** Per-popover UppyUpload. */
  #uppy = null;

  #onDragEnter = null;

  #onDragLeave = null;

  #onDrop = null;

  get label() {
    return this.args.data.hasDarkVariant
      ? i18n("wireframe.canvas.image_drop_replace_dark")
      : i18n("wireframe.canvas.image_drop_add_dark");
  }

  @action
  setup(el) {
    this.#dropEl = el;
    this.#uppy = new UppyUpload(getOwner(this), {
      id: `wireframe-img-dark-${this.args.data.blockKey}-${this.args.data.argName}-${Date.now()}`,
      type: "composer",
      validateUploadedFilesOptions: { imagesOnly: true },
      uploadDropTargetOptions: () => ({ target: this.#dropEl }),
      uploadDone: (upload) => {
        this.args.data.onDarkUpload?.(upload);
      },
    });
    this.#uppy.setup();
    this.#wireDragVisualState();
  }

  @action
  teardown() {
    this.#uppy?.teardown();
    this.#unwireDragVisualState();
  }

  #wireDragVisualState() {
    if (!this.#dropEl) {
      return;
    }
    this.#onDragEnter = () => {
      this.isDragOver = true;
      this.args.data.onPopoverEnter?.();
    };
    this.#onDragLeave = (event) => {
      if (
        event.relatedTarget &&
        event.currentTarget.contains(event.relatedTarget)
      ) {
        return;
      }
      this.isDragOver = false;
      this.args.data.onPopoverLeave?.();
    };
    this.#onDrop = () => {
      this.isDragOver = false;
    };
    this.#dropEl.addEventListener("dragenter", this.#onDragEnter);
    this.#dropEl.addEventListener("dragleave", this.#onDragLeave);
    this.#dropEl.addEventListener("drop", this.#onDrop);
  }

  #unwireDragVisualState() {
    if (!this.#dropEl) {
      return;
    }
    if (this.#onDragEnter) {
      this.#dropEl.removeEventListener("dragenter", this.#onDragEnter);
    }
    if (this.#onDragLeave) {
      this.#dropEl.removeEventListener("dragleave", this.#onDragLeave);
    }
    if (this.#onDrop) {
      this.#dropEl.removeEventListener("drop", this.#onDrop);
    }
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
    >
      {{dIcon "moon"}}
      <span>{{this.label}}</span>
    </div>
  </template>
}
