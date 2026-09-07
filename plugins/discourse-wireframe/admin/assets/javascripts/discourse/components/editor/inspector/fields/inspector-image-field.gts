import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { type ComponentLike } from "@glint/template";
import type { BlockImageSource } from "discourse/blocks/image-value";
import type { ArgSchema } from "discourse/blocks/types";
import UppyImageUploaderUntyped from "discourse/components/uppy-image-uploader";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ImageCompositionControls from "discourse/plugins/discourse-wireframe/discourse/components/editor/image/image-composition-controls";
import {
  type ImageArgValue,
  isImageArgValue,
} from "discourse/plugins/discourse-wireframe/discourse/lib/empty-image-upload";
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import WireframeImageUploadService, {
  type ImageUploadPayload,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-image-upload";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeLayoutSignalService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-signal";
import type WireframeRailService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-rail";
import type WireframeSelectionService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

const URL_PROBE_TIMEOUT_MS = 4000;
const ASPECT_RATIO_EPSILON = 0.02;

type ImageEditorTab = "upload" | "url";

type ImageFieldData = {
  /** FormKit field identifier used by the uploader. */
  id?: string;
  /** FormKit field name identifying the block argument. */
  name: string;
};

// TODO(devxp-typescript-pending): replace `ImageFieldData` once FormKit
// exports the type of the field data yielded by a custom control.

type UrlProbeResult = {
  /** Loaded image width, when the probe succeeded. */
  width?: number;
  /** Loaded image height, when the probe succeeded. */
  height?: number;
  /** Whether loading failed or timed out. */
  failed: boolean;
};

// TODO(devxp-typescript-pending): drop once UppyImageUploader is authored in
// .gts with a real Signature, then import it directly.
const UppyImageUploader = UppyImageUploaderUntyped as unknown as ComponentLike<{
  /** Uppy image uploader arguments. */
  Args: {
    /** Unique uploader identifier. */
    id: string;
    /** Current image URL. */
    imageUrl?: string;
    /** Handles a completed image upload. */
    onUploadDone: (
      /** Successful upload payload. */
      upload: ImageUploadPayload
    ) => void;
    /** Handles deletion of the uploaded image. */
    onUploadDeleted: () => void;
    /** Captures a replacement operation before the upload starts. */
    onUploadStart: () => void;
    /** Core upload type. */
    type: string;
  };
  /** Root uploader element. */
  Element: HTMLElement;
}>;

interface InspectorImageFieldSignature {
  /** Image field identity and canonical argument schema. */
  Args: {
    /** FormKit field data identifying the image argument. */
    custom: ImageFieldData;
    /** Explicit block identity; the inspector adapter supplies it. */
    blockKey?: string;
    /** Closes a floating editor when adjustment moves to the canvas. */
    onReposition?: () => void;
    /** Canonical image argument schema. */
    schema?: ArgSchema;
  };
}

/** Reads live image values so canvas and inspector share one mutation/history path. */
export default class InspectorImageField extends Component<InspectorImageFieldSignature> {
  /** Uploads and writes image argument values. */
  @service declare wireframeImageUpload: WireframeImageUploadService;

  /** Resolves the selected entry's live image value. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Invalidates live reads after layout changes. */
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;

  @service declare wireframeRail: WireframeRailService;

  /** Provides the selected block key. */
  @service declare wireframeSelection: WireframeSelectionService;

  /**
   * URL-tab drafts per variant. Keep the field populated while the
   * user types so switching tabs and coming back doesn't blow away
   * their input. Committed to the saved value on blur.
   */
  @tracked lightUrlDraft: string = "";
  @tracked darkUrlDraft: string = "";

  /**
   * Tab state per variant. Defaults to the value's `source` when set;
   * falls back to `"upload"` for unset variants so the first
   * interaction is the file picker rather than a bare URL input.
   */
  @tracked lightTab: ImageEditorTab = "upload";
  @tracked darkTab: ImageEditorTab = "upload";

  /**
   * Soft warnings per variant (i18n keys). Cleared by the next
   * successful commit.
   */
  @tracked lightWarning: string | null = null;
  @tracked darkWarning: string | null = null;

  /** Captured at mount so pending uploads cannot follow later selections. */
  #targetKey: string | null = null;
  #lightProbeToken = 0;
  #darkProbeToken = 0;
  #lightReplacement: ((source: BlockImageSource) => void) | null = null;
  #darkReplacement: ((source: BlockImageSource) => void) | null = null;

  /**
   * Creates the image editor and seeds its variant tabs and URL drafts.
   *
   * @param owner - Ember owner for the component instance.
   * @param args - Image field identity and argument schema.
   */
  constructor(owner: Owner, args: InspectorImageFieldSignature["Args"]) {
    super(owner, args);
    this.#targetKey = args.blockKey ?? this.wireframeSelection.selectedBlockKey;
    const value = this.liveValue;
    this.lightTab = value?.source ?? "upload";
    this.lightUrlDraft = value?.source === "url" ? (value.url ?? "") : "";
    if (this.args.schema?.allowDark) {
      const dark = value?.dark;
      this.darkTab = dark?.source ?? "upload";
      this.darkUrlDraft = dark?.source === "url" ? (dark.url ?? "") : "";
    }
  }

  get target() {
    return { blockKey: this.blockKey ?? "", argName: this.argName };
  }

  /** Captured when mounted so asynchronous results cannot follow the selection. */
  get blockKey(): string | null {
    return this.#targetKey;
  }

  /**
   * Arg name — FormKit's per-field wrapper carries `name` via
   * `@custom.name`. We don't read FormKit's draft value; we just use
   * its name as the arg key.
   */
  get argName(): string {
    return this.args.custom.name;
  }

  /**
   * Live image-arg value off of `entry.args`. Reading via the
   * trackedObject opens a tracked dep, so any mutation — inspector
   * commit, paste, drop, replace menu — re-renders this field. Also
   * touches `wireframeLayoutSignal.version` so the entry lookup itself
   * re-evaluates after layout mutations (insert / move / replace).
   *
   * @returns Live image value, or `null` when absent.
   */
  get liveValue(): ImageArgValue | null {
    void this.wireframeLayoutSignal.version;
    const key = this.blockKey;
    if (!key) {
      return null;
    }
    const entry = this.wireframeLayoutQuery.findEntryAndOutletSync(key)?.entry;
    const value = entry?.args?.[this.argName];
    return isImageArgValue(value) ? value : null;
  }

  /** Light image variant, or `null` when absent. */
  get lightVariant(): ImageArgValue | null {
    return this.liveValue;
  }

  /** Dark image variant, or `null` when absent. */
  get darkVariant(): ImageArgValue | null {
    return this.liveValue?.dark ?? null;
  }

  /** Whether a dark image variant is currently stored. */
  get hasDarkVariant(): boolean {
    return this.darkVariant !== null;
  }

  /** Whether the schema permits a dark image variant. */
  get allowDark(): boolean {
    return this.args.schema?.allowDark === true;
  }

  get allowFrameResize(): boolean {
    return this.args.schema?.allowResize === true && !this.gridOwnsSize;
  }

  get gridOwnsSize(): boolean {
    void this.wireframeLayoutSignal.version;
    const entry =
      this.blockKey &&
      this.wireframeLayoutQuery.findEntryAndOutletSync(this.blockKey)?.entry;
    return (
      this.args.schema?.allowResize === true &&
      this.wireframeLayoutQuery.isGridCellEntry(entry || null)
    );
  }

  get frameSize() {
    return this.liveValue?.frame ?? this.liveValue;
  }

  /**
   * Returns the formatted warning when the dark variant's intrinsic
   * dimensions diverge from light beyond `ASPECT_RATIO_EPSILON`. The
   * renderer keeps the light frame when switching to the dark source.
   */
  @cached
  get ratioMismatchWarning(): string | null {
    const light = this.lightVariant;
    const dark = this.darkVariant;
    const lightW = light?.width;
    const lightH = light?.height;
    const darkW = dark?.width;
    const darkH = dark?.height;
    if (!lightW || !lightH || !darkW || !darkH) {
      return null;
    }
    const lightRatio = lightW / lightH;
    const darkRatio = darkW / darkH;
    if (Math.abs(lightRatio - darkRatio) <= ASPECT_RATIO_EPSILON) {
      return null;
    }
    return i18n("wireframe.inspector.image.dark_ratio_mismatch", {
      light_w: lightW,
      light_h: lightH,
      dark_w: darkW,
      dark_h: darkH,
    });
  }

  get lightIsResized(): boolean {
    const v = this.lightVariant;
    return this.allowFrameResize && Boolean(v?.frame);
  }

  @action
  editGrid(): void {
    const parent =
      this.blockKey && this.wireframeLayoutQuery.findEntryParent(this.blockKey);
    const key = parent && entryKey(parent);
    if (key) {
      this.wireframeSelection.selectBlock({ key });
      this.wireframeRail.showInspector();
    }
  }

  @action
  focusRequestedField(element: HTMLElement): void {
    const field = this.wireframeRail.inspectorField;
    if (
      !field ||
      field.blockKey !== this.blockKey ||
      field.argName !== this.args.custom.name
    ) {
      return;
    }
    schedule("afterRender", () => {
      if (this.isDestroyed || this.wireframeRail.inspectorField !== field) {
        return;
      }
      const dark =
        field.imageVariant === "dark"
          ? element.querySelector<HTMLDetailsElement>(
              ".wireframe-image-field__dark"
            )
          : null;
      if (dark) {
        dark.open = true;
      }
      const target = dark ?? element;
      target.scrollIntoView({ block: "nearest" });
      target
        .querySelector<HTMLElement>("button, input:not([type=file])")
        ?.focus();
      this.wireframeRail.inspectorField = null;
    });
  }

  @action
  onLightUploadStart(): void {
    this.#lightProbeToken++;
    this.#lightReplacement = this.wireframeImageUpload.beginReplacement(
      this.target
    );
  }

  @action
  onDarkUploadStart(): void {
    this.#darkProbeToken++;
    this.#darkReplacement = this.wireframeImageUpload.beginReplacement(
      this.target,
      "dark"
    );
  }

  @action
  onLightUploadDone(upload: ImageUploadPayload): void {
    if (this.isDestroying) {
      return;
    }
    this.#lightProbeToken++;
    this.lightTab = "upload";
    this.lightWarning = null;
    this.#lightReplacement?.(this.#uploadToVariant(upload));
    this.#lightReplacement = null;
  }

  @action
  onLightUploadDeleted(): void {
    this.#lightProbeToken++;
    this.#darkProbeToken++;
    this.lightUrlDraft = "";
    this.lightWarning = null;
    this.#commitLight(null);
  }

  @action
  onDarkUploadDone(upload: ImageUploadPayload): void {
    if (this.isDestroying) {
      return;
    }
    this.#darkProbeToken++;
    this.darkTab = "upload";
    this.darkWarning = null;
    this.#darkReplacement?.(this.#uploadToVariant(upload));
    this.#darkReplacement = null;
  }

  @action
  onDarkUploadDeleted(): void {
    this.#darkProbeToken++;
    this.darkUrlDraft = "";
    this.darkWarning = null;
    this.#commitDark(null);
  }

  @action
  setLightTab(tab: ImageEditorTab): void {
    this.lightTab = tab;
  }

  @action
  setDarkTab(tab: ImageEditorTab): void {
    this.darkTab = tab;
  }

  @action
  onLightUrlDraftInput(event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    this.lightUrlDraft = event.currentTarget.value;
    this.#lightProbeToken++;
  }

  @action
  onDarkUrlDraftInput(event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    this.darkUrlDraft = event.currentTarget.value;
    this.#darkProbeToken++;
  }

  @action
  commitLightUrl(): void {
    const url = this.lightUrlDraft.trim();
    if (!url) {
      return;
    }
    if (url === this.lightVariant?.url) {
      return;
    }
    const token = ++this.#lightProbeToken;
    const complete = this.wireframeImageUpload.beginReplacement(this.target);
    probeUrl(url).then(({ width, height, failed }) => {
      if (this.isDestroying || token !== this.#lightProbeToken) {
        return;
      }
      this.lightWarning = failed
        ? "wireframe.inspector.image.url_probe_failed"
        : null;
      complete({
        source: "url",
        url,
        width,
        height,
      });
    });
  }

  @action
  commitDarkUrl(): void {
    const url = this.darkUrlDraft.trim();
    if (!url) {
      return;
    }
    if (url === this.darkVariant?.url) {
      return;
    }
    const token = ++this.#darkProbeToken;
    const complete = this.wireframeImageUpload.beginReplacement(
      this.target,
      "dark"
    );
    probeUrl(url).then(({ width, height, failed }) => {
      if (this.isDestroying || token !== this.#darkProbeToken) {
        return;
      }
      this.darkWarning = failed
        ? "wireframe.inspector.image.url_probe_failed"
        : null;
      complete({
        source: "url",
        url,
        width,
        height,
      });
    });
  }

  @action
  resizeFrame(axis: "width" | "height", event: Event): void {
    const input = event.currentTarget;
    const value = this.liveValue;
    const frame = this.frameSize;
    if (
      !(input instanceof HTMLInputElement) ||
      !value ||
      !this.blockKey ||
      !frame?.width ||
      !frame?.height
    ) {
      return;
    }
    const size = input.valueAsNumber;
    if (!Number.isFinite(size) || size <= 0) {
      input.value = String(frame[axis]);
      return;
    }
    if (size !== frame[axis]) {
      this.wireframeImageUpload.setImageArg(this.blockKey, this.argName, {
        ...value,
        frame: { width: frame.width, height: frame.height, [axis]: size },
      });
    }
  }

  @action
  frameKeyDown(axis: "width" | "height", event: KeyboardEvent): void {
    if (event.key === "Enter") {
      event.preventDefault();
      this.resizeFrame(axis, event);
    } else if (
      event.key === "Escape" &&
      event.currentTarget instanceof HTMLInputElement
    ) {
      event.preventDefault();
      event.stopPropagation();
      event.currentTarget.value = String(this.frameSize?.[axis] ?? "");
    }
  }

  @action
  resetLightSize(): void {
    const v = this.lightVariant;
    if (!v || !this.blockKey) {
      return;
    }
    const next = { ...v };
    delete next.frame;
    this.wireframeImageUpload.setImageArg(this.blockKey, this.argName, next);
  }

  #commitLight(next: ImageArgValue | null): void {
    if (!this.blockKey) {
      return;
    }
    if (next == null) {
      this.wireframeImageUpload.setImageArg(this.blockKey, this.argName, null);
      return;
    }
    this.wireframeImageUpload.replaceSource(
      { blockKey: this.blockKey, argName: this.argName },
      next
    );
  }

  #commitDark(next: ImageArgValue | null): void {
    if (!this.blockKey) {
      return;
    }
    const light = this.lightVariant;
    if (!light) {
      return;
    }
    const merged = { ...light };
    if (next == null) {
      delete merged.dark;
    } else {
      merged.dark = next;
    }
    this.wireframeImageUpload.setImageArg(this.blockKey, this.argName, merged);
  }

  #uploadToVariant(upload: ImageUploadPayload): ImageArgValue {
    return {
      source: "upload",
      upload_id: upload.id,
      url: upload.url,
      width: upload.width,
      height: upload.height,
    };
  }

  <template>
    <div
      class="wireframe-image-field"
      data-block-key={{this.blockKey}}
      data-image-arg={{@custom.name}}
      {{didInsert this.focusRequestedField}}
      {{didUpdate this.focusRequestedField this.wireframeRail.inspectorField}}
    >
      <div class="wireframe-image-field__variant">
        <div class="wireframe-image-field__tabs" role="tablist">
          <button
            type="button"
            class={{dConcatClass
              "wireframe-image-field__tab"
              (if
                (eq this.lightTab "upload") "wireframe-image-field__tab--active"
              )
            }}
            role="tab"
            aria-selected={{eq this.lightTab "upload"}}
            {{on "click" (fn this.setLightTab "upload")}}
          >
            {{i18n "wireframe.inspector.image.tab_upload"}}
          </button>
          <button
            type="button"
            class={{dConcatClass
              "wireframe-image-field__tab"
              (if (eq this.lightTab "url") "wireframe-image-field__tab--active")
            }}
            role="tab"
            aria-selected={{eq this.lightTab "url"}}
            {{on "click" (fn this.setLightTab "url")}}
          >
            {{i18n "wireframe.inspector.image.tab_url"}}
          </button>
        </div>

        {{#if (eq this.lightTab "upload")}}
          <UppyImageUploader
            class="wireframe-image-field__uploader no-repeat contain-image"
            @id="{{@custom.id}}-{{@custom.name}}-light"
            @imageUrl={{this.lightVariant.url}}
            @onUploadDone={{this.onLightUploadDone}}
            @onUploadStart={{this.onLightUploadStart}}
            @onUploadDeleted={{this.onLightUploadDeleted}}
            @type="composer"
          />
        {{else}}
          <input
            type="url"
            aria-label={{i18n "wireframe.inspector.image.tab_url"}}
            class="wireframe-image-field__url-input"
            placeholder={{i18n "wireframe.inspector.image.url_placeholder"}}
            value={{this.lightUrlDraft}}
            {{on "input" this.onLightUrlDraftInput}}
            {{on "blur" this.commitLightUrl}}
          />
        {{/if}}

        {{#if this.lightVariant.url}}
          {{#if (eq this.lightTab "url")}}
            <DButton
              class="btn-transparent --danger"
              @icon="trash-can"
              @label="wireframe.inspector.image.remove"
              @action={{this.onLightUploadDeleted}}
            />
          {{/if}}
        {{/if}}

        {{#if this.lightWarning}}
          <div class="wireframe-image-field__warning" role="status">
            {{dIcon "circle-exclamation"}}
            <span>{{i18n this.lightWarning}}</span>
          </div>
        {{/if}}

        {{#if this.lightIsResized}}
          <div class="wireframe-image-field__info" role="status">
            {{dIcon "info-circle"}}
            <span>
              {{i18n
                "wireframe.inspector.image.resized_info"
                width=this.lightVariant.frame.width
                height=this.lightVariant.frame.height
                natural_width=this.lightVariant.width
                natural_height=this.lightVariant.height
              }}
            </span>
            <button
              type="button"
              class="btn btn-flat btn-small wireframe-image-field__info-action"
              {{on "click" this.resetLightSize}}
            >
              {{i18n "wireframe.inspector.image.reset_to_natural"}}
            </button>
          </div>
        {{/if}}
      </div>

      {{#if @schema.allowComposition}}
        {{#if this.lightVariant.url}}
          <ImageCompositionControls
            @target={{this.target}}
            @value={{this.liveValue}}
            @onReposition={{@onReposition}}
          />
        {{/if}}
      {{/if}}

      {{#if this.gridOwnsSize}}
        <fieldset class="wireframe-image-field__frame">
          <legend>{{i18n "wireframe.inspector.image.frame_size"}}</legend>
          <span>{{i18n "wireframe.inspector.image.grid_size"}}</span>
          <span class="wireframe-image-field__grid-help">{{i18n
              "wireframe.inspector.image.grid_size_help"
            }}</span>
          <DButton
            class="btn-default"
            @action={{this.editGrid}}
            @label="wireframe.inspector.image.edit_grid"
          />
        </fieldset>
      {{else if this.allowFrameResize}}
        {{#if this.lightVariant.url}}
          <fieldset class="wireframe-image-field__frame">
            <legend>{{i18n "wireframe.inspector.image.frame_size"}}</legend>
            <label>{{i18n "wireframe.inspector.image.frame_width"}}<input
                type="number"
                min="1"
                value={{this.frameSize.width}}
                {{on "blur" (fn this.resizeFrame "width")}}
                {{on "keydown" (fn this.frameKeyDown "width")}}
              /></label>
            <label>{{i18n "wireframe.inspector.image.frame_height"}}<input
                type="number"
                min="1"
                value={{this.frameSize.height}}
                {{on "blur" (fn this.resizeFrame "height")}}
                {{on "keydown" (fn this.frameKeyDown "height")}}
              /></label>
          </fieldset>
        {{/if}}
      {{/if}}

      {{#if this.allowDark}}
        <details
          class="wireframe-image-field__dark"
          open={{this.hasDarkVariant}}
        >
          <summary>{{i18n "wireframe.inspector.image.dark_label"}}</summary>
          <p class="wireframe-image-field__dark-help">
            {{i18n "wireframe.inspector.image.dark_help"}}
          </p>

          {{#if this.lightVariant.url}}
            <div class="wireframe-image-field__tabs" role="tablist">
              <button
                type="button"
                class={{dConcatClass
                  "wireframe-image-field__tab"
                  (if
                    (eq this.darkTab "upload")
                    "wireframe-image-field__tab--active"
                  )
                }}
                role="tab"
                aria-selected={{eq this.darkTab "upload"}}
                {{on "click" (fn this.setDarkTab "upload")}}
              >
                {{i18n "wireframe.inspector.image.tab_upload"}}
              </button>
              <button
                type="button"
                class={{dConcatClass
                  "wireframe-image-field__tab"
                  (if
                    (eq this.darkTab "url") "wireframe-image-field__tab--active"
                  )
                }}
                role="tab"
                aria-selected={{eq this.darkTab "url"}}
                {{on "click" (fn this.setDarkTab "url")}}
              >
                {{i18n "wireframe.inspector.image.tab_url"}}
              </button>
            </div>

            {{#if (eq this.darkTab "upload")}}
              <UppyImageUploader
                class="wireframe-image-field__uploader no-repeat contain-image"
                @id="{{@custom.id}}-{{@custom.name}}-dark"
                @imageUrl={{this.darkVariant.url}}
                @onUploadDone={{this.onDarkUploadDone}}
                @onUploadStart={{this.onDarkUploadStart}}
                @onUploadDeleted={{this.onDarkUploadDeleted}}
                @type="composer"
              />
            {{else}}
              <input
                type="url"
                aria-label={{i18n "wireframe.inspector.image.tab_url"}}
                class="wireframe-image-field__url-input"
                placeholder={{i18n "wireframe.inspector.image.url_placeholder"}}
                value={{this.darkUrlDraft}}
                {{on "input" this.onDarkUrlDraftInput}}
                {{on "blur" this.commitDarkUrl}}
              />
            {{/if}}

            {{#if this.darkVariant.url}}
              {{#if (eq this.darkTab "url")}}
                <DButton
                  class="btn-transparent --danger"
                  @icon="trash-can"
                  @label="wireframe.inspector.image.remove"
                  @action={{this.onDarkUploadDeleted}}
                />
              {{/if}}
            {{/if}}

            {{#if this.darkWarning}}
              <div class="wireframe-image-field__warning" role="status">
                {{dIcon "circle-exclamation"}}
                <span>{{i18n this.darkWarning}}</span>
              </div>
            {{/if}}

            {{#if this.ratioMismatchWarning}}
              <div class="wireframe-image-field__warning" role="status">
                {{dIcon "circle-exclamation"}}
                <span>{{this.ratioMismatchWarning}}</span>
              </div>
            {{/if}}
          {{else}}
            <p class="wireframe-image-field__dark-disabled">
              {{i18n "wireframe.inspector.image.dark_requires_light"}}
            </p>
          {{/if}}
        </details>
      {{/if}}
    </div>
  </template>
}

/**
 * Probes a URL by loading it as an `<img>` to read `naturalWidth` /
 * `naturalHeight`. Resolves with `{ width, height, failed: false }` on
 * success, `{ failed: true }` on `error` or timeout. Never rejects.
 *
 * @param url - Image URL to probe.
 * @returns Probe result with optional intrinsic dimensions.
 */
function probeUrl(url: string): Promise<UrlProbeResult> {
  return new Promise((resolve) => {
    const img = new Image();
    let settled = false;
    const finish = (result: UrlProbeResult): void => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timer);
      resolve(result);
    };
    const timer = setTimeout(
      () => finish({ failed: true }),
      URL_PROBE_TIMEOUT_MS
    );
    img.onload = () => {
      const width = img.naturalWidth || undefined;
      const height = img.naturalHeight || undefined;
      finish({ width, height, failed: false });
    };
    img.onerror = () => finish({ failed: true });
    img.src = url;
  });
}
