// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * Per-arg overlay for image-typed args. Painted by `block-chrome` for
 * every image arg the block declares.
 *
 * Two modes:
 *   - **Empty arg** (no `url`): renders the empty-state card stretched
 *     across the chrome's content area. Click opens file picker; drop
 *     uploads.
 *   - **Filled arg**: renders as an absolutely-positioned overlay
 *     tracking the rendered image marker's bounding rect. Invisible by
 *     default; lights up with a "drop to replace" hint when a file
 *     drag enters. On drop, replaces the image.
 *
 * For the filled case the overlay tracks the marker via
 * `getBoundingClientRect` (relative to the chrome) and re-measures on
 * the marker's ResizeObserver + window resize, the same pattern the
 * 8-point resize overlay uses.
 *
 * @typedef {Object} ImageArgOverlayArgs
 * @property {string} blockKey
 * @property {string} argName
 * @property {Object} argDef
 * @property {boolean} isEmpty
 * @property {() => Element|null} [getChromeEl] - Required when the arg
 *   is filled so the overlay can position relative to the chrome and
 *   find the rendered marker via querySelector.
 */
export default class ImageArgOverlay extends Component {
  @service wireframe;

  /**
   * `true` while a file drag is hovering this overlay. Drives the
   * `--drag-over` BEM modifier so the target highlights.
   */
  @tracked isDragOver = false;

  /**
   * Marker rect (relative to the chrome) for the filled-state
   * positioning. `null` until first measure.
   */
  @tracked markerRect = null;

  /** ResizeObserver shared between marker + chrome. */
  #observer = null;

  /** Bound `measure` reference for the window listener. */
  #boundMeasure = null;

  /** Hidden file input ref (empty state only). */
  #fileInputEl = null;

  /**
   * Inspector label for the arg, falling back to the arg name when
   * the schema didn't supply one. Used in the empty-state prompt.
   *
   * @returns {string}
   */
  get label() {
    return this.args.argDef?.ui?.label ?? this.args.argName;
  }

  /**
   * `true` when the arg is filled and we have geometry helpers. The
   * filled-state overlay is purely a drop target; an empty arg's
   * overlay is the in-content card.
   *
   * @returns {boolean}
   */
  get rendersAsFilledOverlay() {
    return !this.args.isEmpty && this.args.getChromeEl;
  }

  /**
   * Looks up the rendered image element (`<img>` or `<picture>`) for
   * this arg inside the chrome. The marker is what the wrapped block
   * paints for this image arg; the filled overlay positions itself
   * over it.
   *
   * Note: this overlay ALSO carries `data-block-arg=<argName>` now,
   * so a plain `[data-block-arg=...]` lookup would find ITSELF. The
   * selector is tagged with `img` / `picture` to pick only the
   * visual elements the block painted.
   *
   * @returns {Element|null}
   */
  get markerEl() {
    const chrome = this.args.getChromeEl?.();
    if (!chrome) {
      return null;
    }
    const escaped = CSS.escape(this.args.argName);
    return chrome.querySelector(
      `img[data-block-arg="${escaped}"], picture[data-block-arg="${escaped}"]`
    );
  }

  /**
   * Inline style for the filled overlay's outer div. Positions it
   * absolutely inside the chrome to match the marker's rect. Hidden
   * until first measure.
   *
   * @returns {ReturnType<typeof htmlSafe>}
   */
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

  /* Lifecycle */

  @action
  setupFilled() {
    this.#boundMeasure = () => this.measure();
    this.#observer = new ResizeObserver(this.#boundMeasure);
    this.#attachObserver();
    window.addEventListener("resize", this.#boundMeasure);
    this.measure();
  }

  @action
  teardownFilled() {
    this.#observer?.disconnect();
    this.#observer = null;
    if (this.#boundMeasure) {
      window.removeEventListener("resize", this.#boundMeasure);
      this.#boundMeasure = null;
    }
  }

  #attachObserver() {
    if (!this.#observer) {
      return;
    }
    this.#observer.disconnect();
    const marker = this.markerEl;
    const chrome = this.args.getChromeEl?.();
    if (marker) {
      this.#observer.observe(marker);
    }
    if (chrome) {
      this.#observer.observe(chrome);
    }
  }

  @action
  measure() {
    // structuralVersion bumps on layout mutations; touching it opens
    // a tracked dep so this getter also re-runs on those.
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const marker = this.markerEl;
    const chrome = this.args.getChromeEl?.();
    if (!marker || !chrome) {
      this.markerRect = null;
      return;
    }
    this.#attachObserver();
    const markerRect = marker.getBoundingClientRect();
    const chromeRect = chrome.getBoundingClientRect();
    this.markerRect = {
      top: markerRect.top - chromeRect.top,
      left: markerRect.left - chromeRect.left,
      width: markerRect.width,
      height: markerRect.height,
    };
  }

  /* File input + click-to-pick (empty state only) */

  @action
  registerFileInput(el) {
    this.#fileInputEl = el;
  }

  @action
  onActivate(event) {
    event.stopPropagation();
    this.#markTouched();
    this.#fileInputEl?.click();
  }

  @action
  onKeyActivate(event) {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.onActivate(event);
    }
  }

  #markTouched() {
    this.wireframe.lastTouchedImageArg = this.args.argName;
  }

  @action
  async onFileChosen(event) {
    const input = event.target;
    const file = input?.files?.[0];
    if (!file) {
      return;
    }
    input.value = "";
    await this.#uploadFile(file);
  }

  /* Drag-and-drop (both empty and filled) */

  @action
  onDragEnter(event) {
    if (!dragCarriesImage(event)) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    this.isDragOver = true;
  }

  @action
  onDragOver(event) {
    if (!dragCarriesImage(event)) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    if (event.dataTransfer) {
      event.dataTransfer.dropEffect = "copy";
    }
    this.isDragOver = true;
  }

  @action
  onDragLeave(event) {
    if (
      event.relatedTarget &&
      event.currentTarget.contains(event.relatedTarget)
    ) {
      return;
    }
    this.isDragOver = false;
  }

  @action
  async onDrop(event) {
    event.preventDefault();
    event.stopPropagation();
    this.isDragOver = false;
    const file = pickImageFile(event.dataTransfer);
    if (!file) {
      return;
    }
    this.#markTouched();
    await this.#uploadFile(file);
  }

  @action
  onPointerEnter() {
    this.#markTouched();
  }

  async #uploadFile(file) {
    await this.wireframe.uploadImageForArg(file, {
      blockKey: this.args.blockKey,
      argName: this.args.argName,
    });
  }

  <template>
    {{#if @isEmpty}}
      <div
        class="wireframe-image-arg-overlay wireframe-image-arg-overlay--empty
          {{if this.isDragOver 'wireframe-image-arg-overlay--drag-over'}}"
        data-block-arg={{@argName}}
        role="button"
        tabindex="0"
        {{on "click" this.onActivate}}
        {{on "keydown" this.onKeyActivate}}
        {{on "pointerenter" this.onPointerEnter}}
        {{on "dragenter" this.onDragEnter}}
        {{on "dragover" this.onDragOver}}
        {{on "dragleave" this.onDragLeave}}
        {{on "drop" this.onDrop}}
      >
        <div class="wireframe-image-arg-overlay__content">
          {{dIcon "image"}}
          <span class="wireframe-image-arg-overlay__label">
            {{i18n "wireframe.canvas.image_empty_label_named" label=this.label}}
          </span>
        </div>
      </div>
      <input
        type="file"
        accept="image/*"
        class="wireframe-image-arg-overlay__file-input"
        hidden
        {{on "change" this.onFileChosen}}
        {{didInsert this.registerFileInput}}
      />
    {{else if this.rendersAsFilledOverlay}}
      {{! Drop-to-replace overlay positioned over the rendered image
        marker. Invisible by default — `pointer-events: auto` on the
        outer div lets it catch drag events without blocking clicks
        to the underlying image (which open the Replace / Remove
        menu via the chrome's onClick). The hint label only paints
        when `--drag-over` is on. }}
      <div
        class="wireframe-image-arg-overlay wireframe-image-arg-overlay--filled
          {{if this.isDragOver 'wireframe-image-arg-overlay--drag-over'}}"
        data-block-arg={{@argName}}
        style={{this.filledOverlayStyle}}
        {{didInsert this.setupFilled}}
        {{willDestroy this.teardownFilled}}
        {{on "pointerenter" this.onPointerEnter}}
        {{on "dragenter" this.onDragEnter}}
        {{on "dragover" this.onDragOver}}
        {{on "dragleave" this.onDragLeave}}
        {{on "drop" this.onDrop}}
      >
        {{#if this.isDragOver}}
          <div class="wireframe-image-arg-overlay__content">
            {{dIcon "image"}}
            <span class="wireframe-image-arg-overlay__label">
              {{i18n "wireframe.canvas.image_drop_replace"}}
            </span>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}

/**
 * Returns `true` when the drag event's `dataTransfer` carries at
 * least one file. During `dragenter` / `dragover` the browser hides
 * `item.type` for security in some contexts, so the
 * `dt.types.includes("Files")` fallback is the reliable check.
 *
 * @param {DragEvent} event
 * @returns {boolean}
 */
function dragCarriesImage(event) {
  const dt = event.dataTransfer;
  if (!dt) {
    return false;
  }
  if (dt.items?.length) {
    for (const item of dt.items) {
      if (item.kind === "file") {
        if (!item.type || item.type.startsWith("image/")) {
          return true;
        }
      }
    }
  }
  if (dt.types?.length) {
    return Array.from(dt.types).includes("Files");
  }
  return false;
}

/**
 * Pulls the first image File out of a DataTransfer.
 *
 * @param {DataTransfer|null|undefined} dataTransfer
 * @returns {File|null}
 */
function pickImageFile(dataTransfer) {
  if (!dataTransfer?.files?.length) {
    return null;
  }
  for (const file of dataTransfer.files) {
    if (file.type?.startsWith("image/")) {
      return file;
    }
  }
  return null;
}
