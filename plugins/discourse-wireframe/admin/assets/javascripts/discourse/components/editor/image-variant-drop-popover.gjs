// @ts-check
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
export default class ImageVariantDropPopover extends Component {
  @tracked isDragOver = false;

  /** The drop-target element ref. Set on insert. */
  #dropEl = null;

  /** Per-popover UppyUpload. */
  #uppy = null;

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
  }

  @action
  teardown() {
    this.#uppy?.teardown();
  }

  @action
  onExternalDragEnter() {
    this.isDragOver = true;
    this.args.data.onPopoverEnter?.();
  }

  @action
  onExternalDragLeave() {
    this.isDragOver = false;
    this.args.data.onPopoverLeave?.();
  }

  @action
  onExternalDrop() {
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
