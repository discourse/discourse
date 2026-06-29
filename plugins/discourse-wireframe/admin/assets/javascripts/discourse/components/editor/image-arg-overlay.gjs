// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import UppyUpload from "discourse/lib/uppy/uppy-upload";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import { i18n } from "discourse-i18n";
import { BLOCK_ARG_ATTR } from "discourse/plugins/discourse-wireframe/discourse/lib/editor-dom-contract";
import ImageVariantDropPopover from "./image-variant-drop-popover";

/**
 * Per-arg overlay for image-typed args. Painted by `block-chrome` for
 * every image arg the block declares — empty or filled. The overlay is
 * always absolute-positioned over the arg's rendered marker (an element
 * carrying `data-block-arg="<argName>"`); the block keeps rendering its
 * own markers and the chrome paints the affordance around them.
 *
 * Three behaviors, selected by `@isEmpty` and the marker's attributes:
 *   - **Empty arg** (no `url`): the in-place empty-state card. Click
 *     opens the OS file picker; dropping a file uploads. When the marker
 *     carries `data-drop-fills-block` the overlay spans the whole block
 *     (the marker is just an anchor); otherwise it tracks the marker's
 *     own rect.
 *   - **Filled arg**: invisible drop-to-replace overlay tracking the
 *     marker's rect. Tints on file drag with "Image will be overwritten".
 *   - **Passive marker** (`data-drop-passive`): a full-bleed background
 *     that sits BEHIND the block's content. The overlay is rendered
 *     click-through (`pointer-events: none`) so it can show an empty-state
 *     hint without swallowing clicks meant for the content on top; adding
 *     / replacing the image is handled by the chrome's own click dispatch
 *     and the inspector.
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
 *   on the parent chrome runs AFTER our `setupPositioning` for loaded
 *   layouts (the didInsert order is child-first when both modifiers
 *   are scheduled in the same render pass).
 * @property {File} [pendingFile] - For a passive background marker only:
 *   a file the chrome handed off after a body drop, uploaded through this
 *   overlay's own Uppy pipeline via `uploadHandedFile`.
 */
export default class ImageArgOverlay extends Component {
  @service menu;
  @service wireframe;
  @service wireframeDragOverlay;
  @service wireframeImageUpload;

  /**
   * Marker rect (relative to the chrome) used to position the
   * overlay. `null` until first measure, and whenever the marker is
   * collapsed (e.g. a decorative slot on an unselected card).
   */
  @tracked markerRect = null;

  /**
   * `true` when the resolved marker carries `data-drop-passive` — a
   * full-bleed background behind the block content. Drives the
   * click-through BEM modifier. Read from the template, so it stays
   * unprefixed. Set during `measure`.
   */
  @tracked markerPassive = false;
  /**
   * `true` when the resolved marker carries `data-drop-fills-block` —
   * the image owns the whole block, so the overlay spans the chrome.
   * Read from the template (drives the compact-affordance decision),
   * so it stays unprefixed. Set during `measure`.
   */
  @tracked markerFillsBlock = false;
  /**
   * `true` after an upload through this overlay's pipeline failed, until the
   * next upload starts or succeeds. Drives the in-place "Upload failed" retry
   * affordance on the empty card, so a failed drop / pick isn't silent.
   */
  @tracked uploadFailed = false;

  /**
   * Release callback for this overlay's current image-arg claim, or `null`.
   * The tint itself renders off the coordinator (`isDragOver`); this is only
   * held so a leave releases the exact claim this overlay made.
   */
  #releaseDrop = null;

  /** The overlay's outer `<div>`. Pinned on insert. */
  #overlayEl = null;

  /** Hidden file input ref (interactive empty state only). */
  #fileInputEl = null;

  /** ResizeObserver shared between marker + chrome. */
  #observer = null;

  /** Bound `measure` reference for the window listener. */
  #boundMeasure = null;

  /** Per-overlay UppyUpload. Built lazily in `#bootUppy`. */
  #uppyUpload = null;

  /** Active FloatKit menu instance for the dark-variant popover. */
  #variantMenu = null;

  /**
   * `true` while `#openVariantPopover` is mid-`await` on
   * `menu.show(...)`. Prevents a second `dragenter` (e.g. from an
   * in-out-in flicker that lands inside one runloop tick) from
   * issuing a concurrent `show()` that would toggle the menu
   * closed on its expanded-instance branch.
   */
  #opening = false;

  /**
   * Bumps when the Uppy instance is created so getters that read
   * Uppy's `@tracked` `uploading` / `uploadProgress` actually open
   * the tracked deps on the next template render. Without this the
   * first render evaluates `this.uploading` while `#uppyUpload` is
   * still null, returns `false`, and never re-opens the dep — the
   * progress bar would never appear.
   */
  @tracked _uppyReady = false;

  /**
   * The identity this overlay claims and matches against in the coordinator:
   * the image arg `(blockKey, argName)` plus whether it's the passive
   * full-bleed background marker.
   *
   * @returns {{blockKey: string, argName: string, isPassive: boolean}}
   */
  get #imageArgIdentity() {
    return {
      blockKey: this.args.blockKey,
      argName: this.args.argName,
      isPassive: this.markerPassive,
    };
  }

  /**
   * Whether this overlay's image arg is the single active drag overlay
   * (per the coordinator). Drives the BEM `--drag-over` tint. Matching by
   * identity — not by which surface the cursor is on — means the tint stays
   * while the cursor travels overlay -> dark popover, because the popover
   * re-claims the same identity (only `variant` flips).
   *
   * @returns {boolean}
   */
  get isDragOver() {
    return this.wireframeDragOverlay.isActiveImageArg(this.#imageArgIdentity);
  }

  /**
   * Whether to show the upload-error affordance: a failed upload on an
   * empty arg (the interactive card the user can click to retry).
   *
   * @returns {boolean}
   */
  get showUploadError() {
    return this.uploadFailed && this.args.isEmpty;
  }

  get label() {
    return this.args.argDef?.ui?.label ?? this.args.argName;
  }

  /**
   * `true` when this overlay is the interactive empty-state card —
   * empty AND not a passive background. Only this variant gets the
   * hidden file input, the click-to-pick gesture, and keyboard
   * focus; passive empties are hint-only.
   *
   * @returns {boolean}
   */
  get isInteractiveEmpty() {
    return this.args.isEmpty && !this.markerPassive;
  }

  /**
   * `true` for a small in-place empty affordance — an arg whose marker
   * is neither a whole-block fill nor a full-bleed background (e.g. the
   * media-card avatar slot). These are too small for the icon + label,
   * so the affordance collapses to just the icon.
   *
   * @returns {boolean}
   */
  get isCompact() {
    return this.args.isEmpty && !this.markerPassive && !this.markerFillsBlock;
  }

  /**
   * `true` when this overlay's block is the selected one.
   *
   * @returns {boolean}
   */
  get isSelected() {
    return this.wireframe.selectedBlockKey === this.args.blockKey;
  }

  /**
   * Whether to render the empty-state content (icon + "Add X" label).
   * Always for a non-passive empty arg (its marker is only positioned
   * when revealed, so it self-gates). For a passive background — which
   * `data-drop-fills-block` keeps always positioned — only when the card
   * is selected (the idle hint) OR while a file is dragged over it (drag
   * feedback); otherwise the bare hint would show on every unselected
   * empty card. An in-progress upload takes precedence in the template.
   *
   * @returns {boolean}
   */
  get showEmptyContent() {
    return (
      this.args.isEmpty &&
      (!this.markerPassive || this.isSelected || this.isDragOver)
    );
  }

  /**
   * `true` when the filled overlay's dark-variant popover should
   * be available. Requires the arg to opt into dark variants, a
   * light image to already exist (dark without light is meaningless
   * — the renderer needs a fallback for the default color-scheme
   * media query). Works for passive backgrounds too: the chrome claims this
   * overlay's image-arg while a file is over the body, so `isDragOver` turns
   * true and `syncPopover` opens the popover anchored to this (full-card) overlay.
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
   * that fires AFTER our own `setupPositioning` on loaded layouts.
   */
  get chromeEl() {
    if (!this.#overlayEl) {
      return this.args.getChromeEl?.() ?? null;
    }
    return this.#overlayEl.closest(".wireframe-block-chrome");
  }

  /**
   * The block's rendered marker for this arg. Matches any element
   * carrying `data-block-arg="<argName>"` — `<img>`, `<picture>`, the
   * media-card backdrop `<div>`, or an empty slot — but EXCLUDES the
   * image-arg overlays themselves, which carry the same attribute for
   * the chrome's click dispatch. With one overlay per arg at a time
   * (block-chrome keys the each on emptiness), exactly one block
   * marker matches.
   */
  get markerEl() {
    const chrome = this.chromeEl;
    if (!chrome) {
      return null;
    }
    const escaped = CSS.escape(this.args.argName);
    return chrome.querySelector(
      `[${BLOCK_ARG_ATTR}="${escaped}"]:not(.wireframe-image-arg-overlay)`
    );
  }

  get overlayStyle() {
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
   * A value that changes whenever this block's selection state or the
   * structural layout changes. Threaded into a `didUpdate` modifier so
   * the overlay re-measures when a decorative marker is revealed on
   * selection (the ResizeObserver alone can miss a `display` flip) or
   * the layout reflows on republish.
   *
   * @returns {string}
   */
  get remeasureSignal() {
    const selected =
      this.wireframe.selectedBlockKey === this.args.blockKey ? "1" : "0";
    return `${selected}:${this.wireframe.structuralVersion}`;
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
   * Label text shown inside the filled overlay during a drag. Reflects which
   * variant the drop will replace — light by default, dark when the active
   * overlay's `variant` is dark (the cursor has moved onto the popover).
   */
  get dragOverLabel() {
    if (
      this.wireframeDragOverlay.isActiveImageArg({
        ...this.#imageArgIdentity,
        variant: "dark",
      })
    ) {
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
    this.#bootUppy();
    // Filled (and passive) overlays wire the drop target now; interactive
    // empty overlays defer to `registerFileInput`, which runs a single
    // `setup(el)` once the input mounts. A passive overlay is
    // `pointer-events: none`, so its drop target is inert — the chrome
    // handles body drops and hands the file to `uploadHandedFile` — but
    // Uppy still needs `setup()` so that upload can run.
    if (!this.isInteractiveEmpty) {
      this.#uppyUpload.setup();
      this.#wireUploadFeedback();
    }
  }

  @action
  registerFileInput(el) {
    this.#fileInputEl = el;
    const upload = this.#bootUppy();
    upload.setup(el);
    this.#wireUploadFeedback();
    // A file dropped onto an empty slot creates this image block and stages
    // the file against its key; pick it up here so it uploads through this
    // overlay's own pipeline (progress bar, error state, write to THIS block)
    // exactly like a click-to-pick or a drop onto an existing arg.
    const staged = this.wireframeImageUpload.consumePendingDropFile?.(
      this.args.blockKey,
      this.args.argName
    );
    if (staged) {
      upload.addFiles(staged);
    }
  }

  @action
  teardown() {
    this.#uppyUpload?.teardown();
    this.#observer?.disconnect();
    this.#observer = null;
    if (this.#boundMeasure) {
      window.removeEventListener("resize", this.#boundMeasure);
      this.#boundMeasure = null;
    }
    this.#closeVariantPopover();
  }

  @action
  setupPositioning() {
    this.#boundMeasure = () => this.measure();
    this.#observer = new ResizeObserver(this.#boundMeasure);
    this.#attachObserver();
    window.addEventListener("resize", this.#boundMeasure);
    this.measure();
  }

  @action
  measure() {
    const marker = this.markerEl;
    const chrome = this.chromeEl;
    if (!marker || !chrome) {
      this.markerRect = null;
      return;
    }
    this.markerPassive = marker.hasAttribute("data-drop-passive");
    const fillsBlock = marker.hasAttribute("data-drop-fills-block");
    this.markerFillsBlock = fillsBlock;
    const targetRect = (fillsBlock ? chrome : marker).getBoundingClientRect();
    // A zero-size target means the marker is collapsed — e.g. a
    // decorative slot hidden on an unselected card. Drop the overlay
    // until the marker is revealed. `data-drop-fills-block` measures
    // the chrome (never zero), so those overlays stay visible as
    // anchors regardless of the marker's own display.
    if (targetRect.width === 0 && targetRect.height === 0) {
      this.markerRect = null;
      return;
    }
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

  /* Click-to-pick (interactive empty state) */

  @action
  onActivate(event) {
    // Filled overlays let the click bubble to the chrome, which opens
    // the replace / remove menu. Only the empty state opens the picker.
    if (!this.args.isEmpty) {
      return;
    }
    event.stopPropagation();
    this.wireframeImageUpload.markImageArgTouched(this.args.argName);
    this.#fileInputEl?.click();
  }

  @action
  onKeyActivate(event) {
    if (!this.args.isEmpty) {
      return;
    }
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      this.onActivate(event);
    }
  }

  @action
  onPointerEnter() {
    this.wireframeImageUpload.markImageArgTouched(this.args.argName);
  }

  /* File-drag visual hooks */

  /**
   * Claims the single drag-overlay slot for this image arg as a file is
   * dragged over it (foreground overlays only — the passive background is
   * claimed by the chrome). Claiming replaces any slot-insert preview, so
   * exactly one overlay shows. The tint itself renders off the coordinator
   * via `isDragOver`; the popover's open/close is driven by `syncPopover`.
   *
   * Wired via `{{dDragAndDropExternalTarget}}`; the modifier's deepest-target
   * filter means these fire only when this overlay is the innermost target.
   */
  @action
  onExternalDragEnter() {
    this.#claimImageArg("light");
  }

  @action
  onExternalDragLeave() {
    this.#releaseDrop?.();
  }

  @action
  onExternalDrop() {
    this.#releaseDrop?.();
    this.#closeVariantPopover();
  }

  #claimImageArg(variant) {
    this.#releaseDrop = this.wireframeDragOverlay.claimImageArg({
      ...this.#imageArgIdentity,
      variant,
    });
  }

  /**
   * Opens / closes the dark-variant popover to follow the active overlay.
   * Opens when this image arg becomes the active overlay (foreground drag OR
   * the chrome's passive-background claim) and schedules a graced close when
   * it stops being active. The popover's show/hide TIMING stays a FloatKit
   * concern (hover-grace lets the cursor travel image -> popover); this only
   * decides open-vs-close. Wired to `isDragOver` via `didUpdate`.
   */
  @action
  syncPopover() {
    if (this.isDragOver) {
      if (this.showsVariantPicker) {
        this.#variantMenu?.cancelHoverClose();
        this.#openVariantPopover();
      }
    } else {
      this.#variantMenu?.scheduleHoverClose();
    }
  }

  /**
   * Uploads a file the chrome handed off after a body drop, routing it
   * through this overlay's own Uppy + `uploadDone` pipeline so the
   * progress bar, value write, and block selection all reuse the shared
   * path. Passive markers only; non-passive overlays handle their own
   * drops. Wired to `@pendingFile` via `didUpdate`, so it fires once per
   * dropped file (not on the empty→filled remount).
   */
  @action
  uploadHandedFile() {
    if (!this.markerPassive || !this.args.pendingFile) {
      return;
    }
    this.#bootUppy().addFiles(this.args.pendingFile);
  }

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
   * Tracks upload success / failure on this overlay's Uppy instance so a
   * failed upload surfaces an in-place retry affordance instead of silently
   * leaving the arg empty. Attached after `setup()`, once the underlying
   * Uppy instance exists. `upload` (start) clears the flag so a retry hides
   * the previous error; `upload-error` raises it. Success is cleared by
   * `#applyUpload`.
   */
  #wireUploadFeedback() {
    const uppy = this.#uppyUpload?.uppyWrapper?.uppyInstance;
    if (!uppy) {
      return;
    }
    uppy.on("upload", () => (this.uploadFailed = false));
    uppy.on("upload-error", () => (this.uploadFailed = true));
  }

  /**
   * Routes an `uploadDone` payload into the LIGHT variant of the
   * image arg, preserving any existing dark variant.
   *
   * @param {{id: string, url: string, width: number, height: number}} upload
   */
  #applyUpload(upload) {
    this.uploadFailed = false;
    const current = this.#liveValue();
    const variant = this.#variantFromUpload(upload);
    const existingDark = current?.dark;
    const next = existingDark ? { ...variant, dark: existingDark } : variant;
    this.wireframeImageUpload.setImageArg(
      this.args.blockKey,
      this.args.argName,
      next
    );
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
    this.wireframeImageUpload.setImageArg(
      this.args.blockKey,
      this.args.argName,
      {
        ...light,
        dark,
      }
    );
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
    const entry = this.wireframe.layoutQuery.findEntryAndOutletSync(
      this.args.blockKey
    )?.entry;
    return entry?.args?.[this.args.argName] ?? null;
  }

  /* Dark-variant popover */

  /**
   * Opens the dark-variant popover via FloatKit's menu service. No
   * setTimeout / discourseLater here — FloatKit owns the timing.
   * The `hoverGracePeriod` option keeps the popover open while the
   * cursor travels between image and popover; we drive it manually
   * from our drag handlers via `cancelHoverClose` /
   * `scheduleHoverClose` on the returned instance.
   *
   * The `#opening` flag closes a race where a fast dragenter →
   * dragleave → dragenter sequence lands inside one runloop tick
   * (before `menu.show`'s `afterRender` await resolves). Without
   * it, the second `show()` on the same trigger sees
   * `instance.expanded === true` and toggles the menu closed.
   *
   * After the await, reconcile the hover state — the cursor may
   * have left both targets while we were awaiting `afterRender`,
   * and no further event would fire to close the now-open popover.
   */
  async #openVariantPopover() {
    if (!this.showsVariantPicker || this.#variantMenu || this.#opening) {
      return;
    }
    const triggerEl = this.#overlayEl;
    if (!triggerEl) {
      return;
    }
    this.#opening = true;
    try {
      this.#variantMenu = await this.menu.show(triggerEl, {
        identifier: `wireframe-image-variant-drop-${this.args.argName}`,
        component: ImageVariantDropPopover,
        placement: "bottom-start",
        fallbackPlacements: ["top-start", "bottom-end", "top-end"],
        offset: 0,
        hoverGracePeriod: 200,
        maxWidth: 240,
        onClose: () => {
          // Clear the stale reference when the menu closes on its own
          // (hover-grace timeout, Escape, …) so the next reopen isn't blocked.
          this.#variantMenu = null;
        },
        data: {
          blockKey: this.args.blockKey,
          argName: this.args.argName,
          hasDarkVariant: this.hasDarkVariant,
          onDarkUpload: (upload) => this.#applyDarkUpload(upload),
          // Entering the popover re-claims the SAME image-arg identity with the
          // dark variant, so the tint stays on (the overlay's `isDragOver`
          // still matches) and the label flips to dark; leaving releases.
          // `cancel`/`scheduleHoverClose` keep FloatKit's travel grace.
          onPopoverEnter: () => {
            this.#variantMenu?.cancelHoverClose();
            this.#claimImageArg("dark");
          },
          onPopoverLeave: () => {
            this.#releaseDrop?.();
            this.#variantMenu?.scheduleHoverClose();
          },
        },
      });
      if (!this.isDragOver) {
        this.#variantMenu?.scheduleHoverClose();
      }
    } finally {
      this.#opening = false;
    }
  }

  #closeVariantPopover() {
    if (this.#variantMenu) {
      this.#variantMenu.close();
      this.#variantMenu = null;
    }
  }

  /* Positioning */

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

  <template>
    <div
      class="wireframe-image-arg-overlay
        {{if @isEmpty 'wireframe-image-arg-overlay--empty'}}
        {{unless @isEmpty 'wireframe-image-arg-overlay--filled'}}
        {{if this.markerPassive 'wireframe-image-arg-overlay--passive'}}
        {{if this.isCompact 'wireframe-image-arg-overlay--compact'}}
        {{if this.isDragOver 'wireframe-image-arg-overlay--drag-over'}}
        {{if this.uploading 'wireframe-image-arg-overlay--uploading'}}
        {{if this.showUploadError 'wireframe-image-arg-overlay--error'}}"
      data-block-arg={{@argName}}
      role={{if this.isInteractiveEmpty "button"}}
      tabindex={{if this.isInteractiveEmpty "0"}}
      style={{this.overlayStyle}}
      {{didInsert this.registerOverlay}}
      {{didInsert this.setupPositioning}}
      {{didUpdate this.measure this.remeasureSignal}}
      {{didUpdate this.syncPopover this.isDragOver}}
      {{didUpdate this.uploadHandedFile @pendingFile}}
      {{willDestroy this.teardown}}
      {{on "click" this.onActivate}}
      {{on "keydown" this.onKeyActivate}}
      {{on "pointerenter" this.onPointerEnter}}
      {{dDragAndDropExternalTarget
        accepts="files"
        indicator=false
        onDragEnter=this.onExternalDragEnter
        onDragLeave=this.onExternalDragLeave
        onDrop=this.onExternalDrop
      }}
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
      {{else if this.showUploadError}}
        <div class="wireframe-image-arg-overlay__content">
          {{dIcon "triangle-exclamation"}}
          <span class="wireframe-image-arg-overlay__label">
            {{i18n "wireframe.canvas.image_upload_failed"}}
          </span>
        </div>
      {{else if this.showEmptyContent}}
        <div class="wireframe-image-arg-overlay__content">
          {{dIcon "image"}}
          <span class="wireframe-image-arg-overlay__label">
            {{i18n "wireframe.canvas.image_empty_label_named" label=this.label}}
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
    {{#if this.isInteractiveEmpty}}
      <input
        type="file"
        accept="image/*"
        class="wireframe-image-arg-overlay__file-input"
        hidden
        {{didInsert this.registerFileInput}}
      />
    {{/if}}
  </template>
}
