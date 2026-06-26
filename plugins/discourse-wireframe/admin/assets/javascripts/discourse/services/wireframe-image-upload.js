// @ts-check
import { getOwner } from "@ember/owner";
import Service, { service } from "@ember/service";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import { imageArgEntries } from "discourse/plugins/discourse-wireframe/discourse/lib/empty-image-upload";

/**
 * Owns the editor's image-into-block-arg pipelines: the per-arg upload, OS
 * image-file drops onto empty slots, and system-clipboard image pastes. All
 * three resolve to a single image arg value written through the mutation engine.
 *
 * A peer service in the editor's acyclic dependency graph. It injects only the
 * services downstream of it — the mutation/undo engine (writes the arg), the
 * selection concern (which block/arg a paste or drop targets), the drag overlay
 * (dispatches an external drop's previewed insert), and the session signal (the
 * file-drag guard only fires while the editor is open). It never reaches back up
 * into the kernel; the kernel keeps thin facades so its consumers stay unchanged.
 *
 * It owns window/document listeners (file `dragover`/`drop`, image `paste`)
 * installed at construction and removed on teardown; the composition root looks
 * the service up at boot so the listeners exist before any drag/paste. Each
 * handler also bails when the service is being destroyed, so a listener that
 * fires mid-teardown can't resolve a dependency on a dead owner.
 */
export default class WireframeImageUploadService extends Service {
  @service wireframeDragOverlay;
  @service wireframeEditEngine;
  @service wireframeSelection;
  @service wireframeSession;

  /**
   * Files dropped onto an empty slot, staged by `"blockKey\0argName"` until
   * the freshly-created block's `ImageArgOverlay` mounts and uploads them
   * through its own pipeline. One-shot per entry; cleared on enter / exit.
   *
   * @type {Map<string, File>}
   */
  #pendingDropFiles = new Map();

  /**
   * The most recently interacted-with image arg name for the selected block,
   * recorded via `markImageArgTouched`. Used to route a paste to the right arg
   * on multi-image blocks (e.g. media-card avatar vs cover image); when it
   * doesn't match the selected block's image args, the paste falls back to the
   * first image arg. Read imperatively by the paste handler, so it's a plain
   * private field (not tracked).
   *
   * @type {string|null}
   */
  #lastTouchedImageArg = null;

  /** @type {((event: DragEvent) => void)|null} */
  #handleFileDragOver = null;

  /** @type {((event: DragEvent) => void)|null} */
  #handleFileDrop = null;

  /** @type {((event: ClipboardEvent) => void)|null} */
  #handleImagePaste = null;

  constructor() {
    super(...arguments);
    this.#installFileDragGuard();
    this.#installImagePasteListener();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#uninstallFileDragGuard();
    this.#uninstallImagePasteListener();
  }

  /**
   * Uploads a single File to the Discourse uploads endpoint and writes
   * the result into a block's image arg. Used by the inline editing
   * overlays (click-to-pick, drag-and-drop, paste) so the canvas can
   * mutate image args without the inspector being open.
   *
   * Writes to the specific `blockKey` rather than the currently-selected
   * block, so a slow upload doesn't race with the user clicking around
   * the canvas.
   *
   * One-shot UppyUpload instance per call — uniquely id'd by argName +
   * timestamp to avoid the duplicate-id error when multiple uploads
   * race. The instance tears itself down on success or failure.
   *
   * @param {File|Blob} file
   * @param {Object} options
   * @param {string} options.blockKey - The block whose arg to write.
   * @param {string} options.argName - The image arg name on that block.
   * @returns {Promise<{url: string, width?: number, height?: number}|null>}
   *   The upload result on success, `null` on failure (the consumer
   *   surfaces its own error UI).
   */
  uploadImageForArg(file, { blockKey, argName }) {
    if (!file || !blockKey || !argName) {
      return Promise.resolve(null);
    }
    const owner = getOwner(this);
    const uploadId = `wireframe-image-${argName}-${Date.now()}`;
    return new Promise((resolve) => {
      let settled = false;
      const finish = (result) => {
        if (settled) {
          return;
        }
        settled = true;
        try {
          upload.teardown();
        } catch {
          // Tearing down before Uppy fully boots can throw — safe to ignore.
        }
        resolve(result);
      };

      const upload = new UppyUpload(owner, {
        id: uploadId,
        type: "composer",
        uploadDone: (result) => {
          // The upload can resolve after the editor session is torn down; bail
          // before writing so we don't resolve a dependency on a dead owner.
          if (this.isDestroyed || this.isDestroying) {
            finish(null);
            return;
          }
          // Persist `upload_id` so the server-side cleanup can create an
          // UploadReference for this image when the layout saves; without it
          // the upload would be considered orphan and garbage-collected by
          // Jobs::CleanUpUploads after the 48h grace period.
          this.setImageArg(blockKey, argName, {
            source: "upload",
            upload_id: result.id,
            url: result.url,
            width: result.width,
            height: result.height,
          });
          finish({
            url: result.url,
            width: result.width,
            height: result.height,
          });
        },
      });

      upload.setup();
      upload.uppyWrapper?.uppyInstance?.on("upload-error", () => finish(null));
      upload.addFiles(file);
    });
  }

  /**
   * Completes an OS image-file drop onto an empty, block-accepting slot.
   * The dragover handlers have already published the drop preview (built
   * from the synthetic image-block source), so this runs the pending drop
   * the same way a palette drop does, then hands the dropped file to the
   * freshly-created block.
   *
   * `wireframeDragOverlay.dispatch()` inserts and auto-selects an empty image
   * block at the previewed slot synchronously. Rather than uploading here, the
   * file is STAGED against the new block's key: the block's own `ImageArgOverlay`
   * picks it up as it mounts and uploads it through the overlay pipeline, so
   * the upload shows the per-block progress bar, surfaces errors, and writes
   * only to that block (the overlay always uses its own live key — an upload
   * can never land on a different block). A rejected / invalid drop
   * dispatches nothing, so this is a no-op.
   *
   * @param {File} file - The image file to upload into the new block.
   * @returns {boolean} `true` when a block was created and the file staged.
   */
  completeExternalImageDrop(file) {
    if (!file) {
      return false;
    }
    // Run the pending drop. A false return means the slot rejected the
    // image block, so there's nothing to fill.
    if (!this.wireframeDragOverlay.dispatch()) {
      return false;
    }
    const blockKey = this.wireframeSelection.selectedBlockKey;
    if (!blockKey) {
      return false;
    }
    // Derive the target arg from the inserted block's own schema rather
    // than assuming a name, mirroring how the paste handler picks its arg.
    const argName = imageArgEntries(
      this.wireframeSelection.selectedBlockData?.metadata?.args
    )[0]?.name;
    if (!argName) {
      return false;
    }
    this.stagePendingDropFile(blockKey, argName, file);
    return true;
  }

  /**
   * Stages a dropped file against a block's image arg so the block's
   * `ImageArgOverlay` can upload it through its own pipeline once it mounts.
   * One-shot: `consumePendingDropFile` reads and removes it.
   *
   * @param {string} blockKey
   * @param {string} argName
   * @param {File} file
   */
  stagePendingDropFile(blockKey, argName, file) {
    this.#pendingDropFiles.set(JSON.stringify([blockKey, argName]), file);
  }

  /**
   * Returns and removes the file staged for a block's image arg, or `null`
   * when none was staged. Called by the arg's overlay as it sets up.
   *
   * @param {string} blockKey
   * @param {string} argName
   * @returns {File|null}
   */
  consumePendingDropFile(blockKey, argName) {
    const key = JSON.stringify([blockKey, argName]);
    const file = this.#pendingDropFiles.get(key) ?? null;
    if (file) {
      this.#pendingDropFiles.delete(key);
    }
    return file;
  }

  /**
   * Writes a single arg value into the entry identified by `blockKey`,
   * routing through the same write-path as inspector edits so undo /
   * redo / persistence stay consistent.
   *
   * Low-level write-path shared by the image affordances: the inline
   * image overlays and edit menu call this directly, and helpers like
   * `uploadImageForArg` build the full image-value shape before routing
   * here. Prefer those helpers when constructing a value from scratch.
   *
   * @param {string} blockKey
   * @param {string} argName
   * @param {*} value
   */
  setImageArg(blockKey, argName, value) {
    this.wireframeEditEngine.setArg(blockKey, argName, value);
  }

  /**
   * Records the most recently interacted-with image arg of the selected block,
   * so a subsequent paste routes to it on a multi-image block. Called by the
   * chrome's image-arg overlay on focus / hover / click.
   *
   * @param {string} argName
   */
  markImageArgTouched(argName) {
    this.#lastTouchedImageArg = argName;
  }

  /**
   * Drops any files staged for empty-slot drops. Called by the kernel on editor
   * enter / exit so a stale drop can't be consumed by a later session.
   */
  clearPending() {
    this.#pendingDropFiles.clear();
  }

  /**
   * Window-level `dragover` / `drop` guard. Without this, the browser's
   * default behaviour for an external file drag is to NAVIGATE to the
   * dropped file when the user releases over any element that didn't
   * call `event.preventDefault()`. Per-overlay drop handlers can't
   * always reach their stopPropagation in time (e.g. if the user
   * releases over the chrome outside an image marker), and the
   * resulting full-page navigation throws the editor session away.
   *
   * The guard fires only while the editor session is active and the drag
   * carries files. It always calls `preventDefault` so the browser
   * never gets to navigate; specific overlay handlers still receive
   * the event via normal DOM bubbling and route uploads as needed.
   */
  #installFileDragGuard() {
    if (typeof window === "undefined") {
      return;
    }
    this.#handleFileDragOver = (event) => {
      if (this.isDestroyed || this.isDestroying) {
        return;
      }
      if (!this.wireframeSession.active) {
        return;
      }
      if (!event.dataTransfer?.types?.includes?.("Files")) {
        return;
      }
      event.preventDefault();
    };
    this.#handleFileDrop = (event) => {
      if (this.isDestroyed || this.isDestroying) {
        return;
      }
      if (!this.wireframeSession.active) {
        return;
      }
      if (!event.dataTransfer?.types?.includes?.("Files")) {
        return;
      }
      event.preventDefault();
      // Safety net for external (file) drags, which have no element source
      // modifier to run `endDrag`: this bubbling-phase listener fires after
      // PDND's capture-phase target `onDrop` (which already dispatched), so
      // clearing the overlay here can't wipe an unconsumed dispatch.
      this.wireframeDragOverlay.clear();
    };
    window.addEventListener("dragover", this.#handleFileDragOver, false);
    window.addEventListener("drop", this.#handleFileDrop, false);
  }

  #uninstallFileDragGuard() {
    if (this.#handleFileDragOver) {
      window.removeEventListener("dragover", this.#handleFileDragOver, false);
      this.#handleFileDragOver = null;
    }
    if (this.#handleFileDrop) {
      window.removeEventListener("drop", this.#handleFileDrop, false);
      this.#handleFileDrop = null;
    }
  }

  /**
   * Installs a document-level `paste` listener that routes image data
   * from the system clipboard into the selected block's image arg. The
   * listener is always installed (it's cheap and only acts when a
   * block with image args is selected), and torn down when the
   * service is destroyed.
   *
   * Guarded so the handler ignores pastes that originate inside
   * native text inputs / contenteditables outside the editor — those
   * keep their default browser behaviour.
   */
  #installImagePasteListener() {
    if (typeof document === "undefined") {
      return;
    }
    this.#handleImagePaste = (event) => {
      if (this.isDestroyed || this.isDestroying) {
        return;
      }
      this.#onImagePaste(event);
    };
    document.addEventListener("paste", this.#handleImagePaste, true);
  }

  #uninstallImagePasteListener() {
    if (this.#handleImagePaste) {
      document.removeEventListener("paste", this.#handleImagePaste, true);
      this.#handleImagePaste = null;
    }
  }

  /**
   * Paste handler. No-ops unless all of:
   *   - A block is selected on the canvas
   *   - That block declares one or more image args
   *   - The clipboard carries at least one image file
   *   - The paste target isn't a text input outside the editor scope
   *
   * When everything lines up, the handler picks the target arg (the
   * last-touched image arg if set and still valid, else the first image arg
   * declared on the block) and routes the file through the shared upload helper.
   * Gates on the selected block rather than the session flag — selection is
   * cleared on exit, so a post-exit paste no-ops on the missing key.
   *
   * @param {ClipboardEvent} event
   */
  async #onImagePaste(event) {
    const blockKey = this.wireframeSelection.selectedBlockKey;
    if (!blockKey) {
      return;
    }
    const imageArgs = imageArgEntries(
      this.wireframeSelection.selectedBlockData?.metadata?.args
    ).map((entry) => entry.name);
    if (imageArgs.length === 0) {
      return;
    }
    if (this.#pasteTargetIsTextInput(event.target)) {
      return;
    }
    const file = this.#pickImageFromClipboard(event.clipboardData);
    if (!file) {
      return;
    }
    event.preventDefault();

    const argName =
      this.#lastTouchedImageArg && imageArgs.includes(this.#lastTouchedImageArg)
        ? this.#lastTouchedImageArg
        : imageArgs[0];

    await this.uploadImageForArg(file, { blockKey, argName });
  }

  /**
   * Returns `true` when the paste's `event.target` is a native text
   * surface (input, textarea, contenteditable) that isn't part of the
   * editor's own chrome — in which case the native paste behaviour
   * (insert text / image into the field) is the expected outcome and
   * we shouldn't hijack it.
   *
   * Inputs INSIDE the editor chrome (e.g. an inspector field) are
   * also skipped — the inspector already has its own image controls.
   *
   * @param {EventTarget|null} target
   * @returns {boolean}
   */
  #pasteTargetIsTextInput(target) {
    if (!(target instanceof Element)) {
      return false;
    }
    if (target.closest("input, textarea, [contenteditable]")) {
      return true;
    }
    return false;
  }

  /**
   * Pulls the first image File out of a clipboard payload. Falls back
   * to `items` (where the file representation lives in some browsers
   * for image-only pastes) when `files` is empty.
   *
   * @param {DataTransfer|null|undefined} clipboardData
   * @returns {File|null}
   */
  #pickImageFromClipboard(clipboardData) {
    if (!clipboardData) {
      return null;
    }
    if (clipboardData.files?.length) {
      for (const f of clipboardData.files) {
        if (f.type?.startsWith("image/")) {
          return f;
        }
      }
    }
    if (clipboardData.items?.length) {
      for (const item of clipboardData.items) {
        if (item.kind === "file" && item.type?.startsWith("image/")) {
          const file = item.getAsFile();
          if (file) {
            return file;
          }
        }
      }
    }
    return null;
  }
}
