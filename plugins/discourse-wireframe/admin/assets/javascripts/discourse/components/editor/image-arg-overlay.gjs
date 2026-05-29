// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ImageVariantDropPopover from "./image-variant-drop-popover";

/**
 * Per-arg overlay for image-typed args. Painted by `block-chrome` for
 * every image arg the block declares.
 *
 * Two modes:
 *   - **Empty arg** (no `url`): the in-content empty-state card.
 *     Click opens the OS file picker; dropping a file uploads.
 *   - **Filled arg**: absolute-positioned overlay tracking the
 *     rendered image marker's bounding rect (or the chrome's rect
 *     when the marker carries `data-drop-fills-block`). Invisible by
 *     default; tints on file drag with "Image will be overwritten".
 *
 * Drop pipelines are independent:
 *   - Drop on the OVERLAY → replaces the LIGHT variant (preserving
 *     any existing dark variant). Wired via this component's own
 *     `UppyUpload` instance + Uppy's `@uppy/drop-target` plugin.
 *   - Drop on the FLOATING popover (rendered when `allowDark` + a
 *     light image is set) → replaces (or adds) the DARK variant.
 *     The popover hosts its own `UppyUpload` so the two variants
 *     never collide. The popover is shown via FloatKit's
 *     `menu.show()` with `hoverGracePeriod` so the cursor can
 *     travel from image → popover → image without the menu closing.
 *
 * @typedef {Object} ImageArgOverlayArgs
 * @property {string} blockKey
 * @property {string} argName
 * @property {Object} argDef
 * @property {boolean} isEmpty
 * @property {() => Element|null} [getChromeEl] - Provided by block-
 *   chrome but we don't rely on its component lifecycle. The
 *   `chromeEl` getter walks up from the overlay's own element via
 *   `closest(".wireframe-block-chrome")` because `captureChromeEl`
 *   on the parent chrome runs AFTER our `setupFilled` for loaded
 *   layouts (the didInsert order is child-first when both modifiers
 *   are scheduled in the same render pass).
 */
export default class ImageArgOverlay extends Component {
  @service menu;
  @service wireframe;

  /**
   * `true` while a file drag is hovering this overlay OR the
   * dark-variant popover. Drives the BEM `--drag-over` modifier on
   * the overlay so the tint stays visible while the cursor is over
   * either surface.
   */
  @tracked isDragOver = false;

  /**
   * Marker rect (relative to the chrome) used to position the
   * filled overlay. `null` until first measure.
   */
  @tracked markerRect = null;

  /**
   * `true` while the cursor is over the dark-variant popover. Lets
   * the overlay keep its tint AND update its label text to reflect
   * the impending dark replacement.
   */
  @tracked popoverHovered = false;

  /** The overlay's outer `<div>`. Pinned on insert. */
  #overlayEl = null;
  /** Hidden file input ref (empty state only). */
  #fileInputEl = null;
  /** ResizeObserver shared between marker + chrome. */
  #observer = null;
  /** Bound `measure` reference for the window listener. */
  #boundMeasure = null;
  /** Per-overlay UppyUpload. Built lazily in `#bootUppy`. */
  #uppyUpload = null;
  /**
   * Internal handlers for the thin dragenter/dragleave listeners
   * we install on top of Uppy's own listeners. Uppy handles the
   * upload routing; these toggle `isDragOver` for the tint and
   * drive the variant popover's open/close timing.
   */
  #onDragEnter = null;
  #onDragLeave = null;
  #onDrop = null;
  /** Active FloatKit menu instance for the dark-variant popover. */
  #variantMenu = null;
  /**
   * Bumps when the Uppy instance is created so getters that read
   * Uppy's `@tracked` `uploading` / `uploadProgress` actually open
   * the tracked deps on the next template render. Without this the
   * first render evaluates `this.uploading` while `#uppyUpload` is
   * still null, returns `false`, and never re-opens the dep — the
   * progress bar would never appear.
   */
  @tracked _uppyReady = false;

  #bootUppy() {
    if (this.#uppyUpload) {
      return this.#uppyUpload;
    }
    this.#uppyUpload = new UppyUpload(getOwner(this), {
      id: `wireframe-img-${this.args.blockKey}-${this.args.argName}`,
      type: "composer",
      validateUploadedFilesOptions: { imagesOnly: true },
      uploadDropTargetOptions: () => ({ target: this.#overlayEl }),
      uploadDone: (upload) => this.#applyUpload(upload),
    });
    this._uppyReady = true;
    return this.#uppyUpload;
  }

  /**
   * Routes an `uploadDone` payload into the LIGHT variant of the
   * image arg, preserving any existing dark variant.
   *
   * @param {{id: string, url: string, width: number, height: number}} upload
   */
  #applyUpload(upload) {
    const current = this.#liveValue();
    const variant = this.#variantFromUpload(upload);
    const existingDark = current?.dark;
    const next = existingDark ? { ...variant, dark: existingDark } : variant;
    this.wireframe._setImageArg(this.args.blockKey, this.args.argName, next);
    this.#selectOwningBlock();
  }

  /**
   * Routes an upload to the DARK variant — preserving light. Wired
   * to the popover's `onDarkUpload` callback.
   *
   * @param {{id: string, url: string, width: number, height: number}} upload
   */
  #applyDarkUpload(upload) {
    const current = this.#liveValue();
    if (!current) {
      // Defensive — dark without light makes no semantic sense.
      this.#applyUpload(upload);
      return;
    }
    const light = { ...current };
    delete light.dark;
    const dark = this.#variantFromUpload(upload);
    this.wireframe._setImageArg(this.args.blockKey, this.args.argName, {
      ...light,
      dark,
    });
    this.#selectOwningBlock();
    this.#closeVariantPopover();
  }

  /**
   * Selects this overlay's block after a successful drop so the
   * inspector reflects the freshly uploaded image without a follow-
   * up click. Idempotent if the block is already selected.
   */
  #selectOwningBlock() {
    if (this.wireframe.selectedBlockKey === this.args.blockKey) {
      return;
    }
    this.wireframe.selectBlock({ key: this.args.blockKey });
  }

  #variantFromUpload(upload) {
    return {
      source: "upload",
      upload_id: upload.id,
      url: upload.url,
      width: upload.width,
      height: upload.height,
      naturalWidth: upload.width,
      naturalHeight: upload.height,
    };
  }

  #liveValue() {
    const entry = this.wireframe._findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    return entry?.args?.[this.args.argName] ?? null;
  }

  /* Computed state */

  get label() {
    return this.args.argDef?.ui?.label ?? this.args.argName;
  }

  get rendersAsFilledOverlay() {
    return !this.args.isEmpty && this.args.getChromeEl;
  }

  /**
   * `true` when the filled overlay's dark-variant popover should
   * be available. Requires the arg to opt into dark variants AND a
   * light image to already exist (dark without light is meaningless
   * — the renderer needs a fallback for the default color-scheme
   * media query).
   */
  get showsVariantPicker() {
    if (!this.args.argDef?.allowDark) {
      return false;
    }
    return !this.args.isEmpty;
  }

  get hasDarkVariant() {
    return !!this.#liveValue()?.dark?.url;
  }

  /**
   * Walks the DOM up from the overlay element to find the chrome.
   * Bypasses the chrome component's `captureChromeEl` lifecycle —
   * that fires AFTER our own `setupFilled` on loaded layouts.
   */
  get chromeEl() {
    if (!this.#overlayEl) {
      return this.args.getChromeEl?.() ?? null;
    }
    return this.#overlayEl.closest(".wireframe-block-chrome");
  }

  get markerEl() {
    const chrome = this.chromeEl;
    if (!chrome) {
      return null;
    }
    const escaped = CSS.escape(this.args.argName);
    return chrome.querySelector(
      `img[data-block-arg="${escaped}"], picture[data-block-arg="${escaped}"]`
    );
  }

  get filledOverlayStyle() {
    const r = this.markerRect;
    if (!r) {
      return trustHTML("display: none;");
    }
    return trustHTML(
      `position: absolute; top: ${r.top}px; left: ${r.left}px; ` +
        `width: ${r.width}px; height: ${r.height}px;`
    );
  }

  /**
   * `true` when an upload is in progress. Reads `_uppyReady` first
   * so the tracked dep is opened before Uppy's `uploading` (which
   * is undefined while `#uppyUpload` is null on the first render).
   */
  get uploading() {
    // eslint-disable-next-line no-unused-vars
    const _r = this._uppyReady;
    return !!this.#uppyUpload?.uploading;
  }

  get uploadProgress() {
    // eslint-disable-next-line no-unused-vars
    const _r = this._uppyReady;
    return this.#uppyUpload?.uploadProgress ?? 0;
  }

  get progressBarStyle() {
    return trustHTML(`width: ${this.uploadProgress}%;`);
  }

  /**
   * Label text shown inside the filled overlay during a drag.
   * Reflects which variant the drop will replace — light by
   * default, dark when the cursor has moved onto the popover.
   */
  get dragOverLabel() {
    if (this.popoverHovered) {
      return this.hasDarkVariant
        ? i18n("wireframe.canvas.image_drop_replace_dark")
        : i18n("wireframe.canvas.image_drop_add_dark");
    }
    return i18n("wireframe.canvas.image_drop_replace");
  }

  /* Lifecycle */

  @action
  registerOverlay(el) {
    this.#overlayEl = el;
    this.#bootUppy().setup();
    this.#wireDragVisualState();
  }

  @action
  registerFileInput(el) {
    this.#fileInputEl = el;
    this.#bootUppy().setup(el);
  }

  @action
  teardown() {
    this.#uppyUpload?.teardown();
    this.#unwireDragVisualState();
    this.#observer?.disconnect();
    this.#observer = null;
    if (this.#boundMeasure) {
      window.removeEventListener("resize", this.#boundMeasure);
      this.#boundMeasure = null;
    }
    this.#closeVariantPopover();
  }

  /**
   * Uppy's DropTarget plugin handles the upload pipeline but
   * doesn't expose a "drag is over" hook for highlight styling.
   * These listeners drive the tint AND the variant popover.
   * Neither calls preventDefault — Uppy already does.
   */
  #wireDragVisualState() {
    if (!this.#overlayEl) {
      return;
    }
    this.#onDragEnter = () => {
      this.isDragOver = true;
      // Cancel any pending close from a brief excursion onto the
      // popover and back — re-using FloatKit's own hover-grace
      // primitive so we don't roll a parallel timer.
      this.#variantMenu?.cancelHoverClose();
      this.#openVariantPopover();
    };
    this.#onDragLeave = (event) => {
      if (
        event.relatedTarget &&
        event.currentTarget.contains(event.relatedTarget)
      ) {
        return;
      }
      this.isDragOver = false;
      // The cursor may be heading into the popover. Defer the
      // close to FloatKit's hoverGracePeriod; the popover will
      // cancel it via `cancelHoverClose` on its own dragenter.
      this.#variantMenu?.scheduleHoverClose();
    };
    this.#onDrop = () => {
      this.isDragOver = false;
      this.#closeVariantPopover();
    };
    this.#overlayEl.addEventListener("dragenter", this.#onDragEnter);
    this.#overlayEl.addEventListener("dragleave", this.#onDragLeave);
    this.#overlayEl.addEventListener("drop", this.#onDrop);
  }

  #unwireDragVisualState() {
    if (!this.#overlayEl) {
      return;
    }
    if (this.#onDragEnter) {
      this.#overlayEl.removeEventListener("dragenter", this.#onDragEnter);
    }
    if (this.#onDragLeave) {
      this.#overlayEl.removeEventListener("dragleave", this.#onDragLeave);
    }
    if (this.#onDrop) {
      this.#overlayEl.removeEventListener("drop", this.#onDrop);
    }
  }

  /**
   * Opens the dark-variant popover via FloatKit's menu service. No
   * setTimeout / discourseLater here — FloatKit owns the timing.
   * The `hoverGracePeriod` option keeps the popover open while the
   * cursor travels between image and popover (we drive it manually
   * from our drag handlers via `cancelHoverClose` /
   * `scheduleHoverClose` on the returned instance).
   */
  async #openVariantPopover() {
    if (!this.showsVariantPicker || this.#variantMenu) {
      return;
    }
    const triggerEl = this.#overlayEl;
    if (!triggerEl) {
      return;
    }
    this.#variantMenu = await this.menu.show(triggerEl, {
      identifier: `wireframe-image-variant-drop-${this.args.argName}`,
      component: ImageVariantDropPopover,
      placement: "bottom-start",
      fallbackPlacements: ["top-start", "bottom-end", "top-end"],
      offset: 0,
      hoverGracePeriod: 200,
      maxWidth: 240,
      data: {
        blockKey: this.args.blockKey,
        argName: this.args.argName,
        hasDarkVariant: this.hasDarkVariant,
        onDarkUpload: (upload) => this.#applyDarkUpload(upload),
        onPopoverEnter: () => {
          this.popoverHovered = true;
          this.isDragOver = true;
          this.#variantMenu?.cancelHoverClose();
        },
        onPopoverLeave: () => {
          this.popoverHovered = false;
          this.#variantMenu?.scheduleHoverClose();
        },
      },
    });
  }

  #closeVariantPopover() {
    this.popoverHovered = false;
    if (this.#variantMenu) {
      this.#variantMenu.close();
      this.#variantMenu = null;
    }
  }

  /* Filled-state positioning */

  @action
  setupFilled() {
    this.#boundMeasure = () => this.measure();
    this.#observer = new ResizeObserver(this.#boundMeasure);
    this.#attachObserver();
    window.addEventListener("resize", this.#boundMeasure);
    this.measure();
  }

  #attachObserver() {
    if (!this.#observer) {
      return;
    }
    this.#observer.disconnect();
    const marker = this.markerEl;
    const chrome = this.chromeEl;
    if (marker) {
      this.#observer.observe(marker);
    }
    if (chrome) {
      this.#observer.observe(chrome);
    }
  }

  @action
  measure() {
    const marker = this.markerEl;
    const chrome = this.chromeEl;
    if (!marker || !chrome) {
      this.markerRect = null;
      return;
    }
    const fillsBlock = marker.hasAttribute("data-drop-fills-block");
    const targetRect = (fillsBlock ? chrome : marker).getBoundingClientRect();
    const chromeRect = chrome.getBoundingClientRect();
    const next = {
      top: targetRect.top - chromeRect.top,
      left: targetRect.left - chromeRect.left,
      width: targetRect.width,
      height: targetRect.height,
    };
    const prev = this.markerRect;
    if (
      prev &&
      prev.top === next.top &&
      prev.left === next.left &&
      prev.width === next.width &&
      prev.height === next.height
    ) {
      return;
    }
    this.markerRect = next;
  }

  /* Click-to-pick (empty state) */

  @action
  onActivate(event) {
    event.stopPropagation();
    this.wireframe.lastTouchedImageArg = this.args.argName;
    this.#fileInputEl?.click();
  }

  @action
  onKeyActivate(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.onActivate(event);
    }
  }

  @action
  onPointerEnter() {
    this.wireframe.lastTouchedImageArg = this.args.argName;
  }

  <template>
    {{#if @isEmpty}}
      <div
        class="wireframe-image-arg-overlay wireframe-image-arg-overlay--empty
          {{if this.isDragOver 'wireframe-image-arg-overlay--drag-over'}}
          {{if this.uploading 'wireframe-image-arg-overlay--uploading'}}"
        data-block-arg={{@argName}}
        role="button"
        tabindex="0"
        {{didInsert this.registerOverlay}}
        {{willDestroy this.teardown}}
        {{on "click" this.onActivate}}
        {{on "keydown" this.onKeyActivate}}
        {{on "pointerenter" this.onPointerEnter}}
      >
        {{#if this.uploading}}
          <div class="wireframe-image-arg-overlay__progress">
            <div class="wireframe-image-arg-overlay__progress-track">
              <div
                class="wireframe-image-arg-overlay__progress-bar"
                style={{this.progressBarStyle}}
              ></div>
            </div>
            <span class="wireframe-image-arg-overlay__progress-label">
              {{i18n
                "wireframe.canvas.image_uploading"
                progress=this.uploadProgress
              }}
            </span>
          </div>
        {{else}}
          <div class="wireframe-image-arg-overlay__content">
            {{dIcon "image"}}
            <span class="wireframe-image-arg-overlay__label">
              {{i18n
                "wireframe.canvas.image_empty_label_named"
                label=this.label
              }}
            </span>
          </div>
        {{/if}}
      </div>
      <input
        type="file"
        accept="image/*"
        class="wireframe-image-arg-overlay__file-input"
        hidden
        {{didInsert this.registerFileInput}}
      />
    {{else if this.rendersAsFilledOverlay}}
      <div
        class="wireframe-image-arg-overlay wireframe-image-arg-overlay--filled
          {{if this.isDragOver 'wireframe-image-arg-overlay--drag-over'}}
          {{if this.uploading 'wireframe-image-arg-overlay--uploading'}}"
        data-block-arg={{@argName}}
        style={{this.filledOverlayStyle}}
        {{didInsert this.registerOverlay}}
        {{didInsert this.setupFilled}}
        {{willDestroy this.teardown}}
        {{on "pointerenter" this.onPointerEnter}}
      >
        {{#if this.uploading}}
          <div class="wireframe-image-arg-overlay__progress">
            <div class="wireframe-image-arg-overlay__progress-track">
              <div
                class="wireframe-image-arg-overlay__progress-bar"
                style={{this.progressBarStyle}}
              ></div>
            </div>
            <span class="wireframe-image-arg-overlay__progress-label">
              {{i18n
                "wireframe.canvas.image_uploading"
                progress=this.uploadProgress
              }}
            </span>
          </div>
        {{else if this.isDragOver}}
          <div class="wireframe-image-arg-overlay__content">
            {{dIcon "image"}}
            <span class="wireframe-image-arg-overlay__label">
              {{this.dragOverLabel}}
            </span>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
