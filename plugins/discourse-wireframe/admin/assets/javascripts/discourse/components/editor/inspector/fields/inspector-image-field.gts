import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
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
import FKControlInputUntyped from "discourse/form-kit/components/fk/control/input";
import noop from "discourse/helpers/noop";
import type A11yService from "discourse/services/a11y";
import { and, eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropExternalTarget, {
  type ExternalDropTargetEvent,
} from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
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

/** TODO(typescript-pending): remove when FormKit input exports a signature. */
const FKControlInput = FKControlInputUntyped as unknown as ComponentLike<{
  Args: {
    type: "number";
    after: string;
    field: { hasExplicitType: boolean; value?: number; set: () => void };
  };
  Element: HTMLInputElement;
}>;

type ImageFieldData = {
  /** FormKit field identifier used by the uploader. */
  id?: string;
  /** FormKit field name identifying the block argument. */
  name: string;
  /** Whether the owning field is locked. */
  disabled?: boolean;
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

interface ImageSourceSignature {
  Args: {
    /** Source displayed in the summary. */
    value: BlockImageSource | null;
    /** Translated source name. */
    label: string;
    /** Stable upload destination, including its variant. */
    target: { blockKey: string; argName: string; variant: "light" | "dark" };
    /** Shows the initial default chooser directly, without a disclosure. */
    empty?: boolean;
    /** Prevents drops into locked fields. */
    disabled?: boolean;
  };
  Blocks: {
    /** Source chooser rendered inside the disclosure, or directly when empty. */
    default: [];
  };
  Element: HTMLElement;
}

class ImageSource extends Component<ImageSourceSignature> {
  @service declare a11y: A11yService;
  @service declare wireframeImageUpload: WireframeImageUploadService;

  @tracked uploadFailed = false;
  @tracked uploading = false;
  @tracked uploadProgress: number | undefined;

  @action
  canDrop(): boolean {
    return !this.args.disabled && !this.uploading;
  }

  @action
  async dropFile({ source }: ExternalDropTargetEvent): Promise<void> {
    const file = source.getFiles()[0];
    if (!file || !this.canDrop()) {
      return;
    }
    this.uploading = true;
    this.uploadFailed = false;
    this.uploadProgress = undefined;
    this.a11y.announce(i18n("upload_selector.uploading"));
    try {
      const result = await this.wireframeImageUpload.uploadImageForArg(file, {
        ...this.args.target,
        onProgress: this.updateUploadProgress,
      });
      if (!this.isDestroying) {
        this.uploadFailed = !result;
      }
    } catch {
      if (!this.isDestroying) {
        this.uploadFailed = true;
      }
    } finally {
      if (!this.isDestroying) {
        this.uploading = false;
        if (this.uploadFailed) {
          this.a11y.announce(i18n("wireframe.inspector.image.change_failed"));
        }
      }
    }
  }

  @action
  updateUploadProgress(progress: number): void {
    if (!this.isDestroying && this.uploading) {
      this.uploadProgress = progress;
    }
  }

  <template>
    {{#if @empty}}
      <div class="wireframe-image-field__empty" ...attributes>
        {{yield}}
      </div>
    {{else}}
      <details ...attributes>
        <summary
          class="wireframe-image-field__source"
          aria-busy={{if this.uploading "true"}}
          {{dDragAndDropExternalTarget
            accepts="files"
            canDrop=this.canDrop
            onDrop=this.dropFile
          }}
        >
          {{#if @value.url}}
            <img src={{@value.url}} alt="" />
          {{else}}
            <span class="wireframe-image-field__placeholder">{{dIcon
                "plus"
              }}</span>
          {{/if}}
          <span class="wireframe-image-field__source-label">
            {{@label}}
            {{#if this.uploading}}
              <small class="wireframe-image-field__upload-status">
                {{i18n "upload_selector.uploading"}}
                <progress
                  aria-label={{i18n "upload_selector.uploading"}}
                  max="100"
                  value={{this.uploadProgress}}
                />
              </small>
            {{else if this.uploadFailed}}
              <span class="wireframe-image-field__warning">{{i18n
                  "wireframe.inspector.image.change_failed"
                }}</span>
            {{else if @value.width}}
              <small><bdi dir="ltr">{{@value.width}}
                  ×
                  {{@value.height}}</bdi></small>
            {{/if}}
          </span>
          {{dIcon "chevron-down"}}
        </summary>
        {{yield}}
      </details>
    {{/if}}
  </template>
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

  get allowDark(): boolean {
    return (
      this.args.schema?.allowDark === true && Boolean(this.lightVariant?.url)
    );
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
        .querySelector<HTMLElement>("summary, button, input:not([type=file])")
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
      <ImageSource
        class="wireframe-image-field__variant"
        @disabled={{@custom.disabled}}
        @empty={{unless this.lightVariant.url true}}
        @label={{i18n "wireframe.inspector.image.default_label"}}
        @target={{hash
          blockKey=this.target.blockKey
          argName=this.target.argName
          variant="light"
        }}
        @value={{this.lightVariant}}
      >
        <div class="wireframe-image-field__source-editor">
          <div class="wireframe-image-field__tabs" role="tablist">
            <button
              type="button"
              class={{dConcatClass
                "wireframe-image-field__tab"
                (if
                  (eq this.lightTab "upload")
                  "wireframe-image-field__tab--active"
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
                (if
                  (eq this.lightTab "url") "wireframe-image-field__tab--active"
                )
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
              class="wireframe-image-field__uploader"
              @id="{{@custom.id}}-{{@custom.name}}-light"
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
            <DButton
              class="wireframe-image-field__remove btn-transparent btn-small --danger"
              @icon="trash-can"
              @label="wireframe.inspector.image.remove"
              @action={{this.onLightUploadDeleted}}
            />
          {{/if}}

          {{#if this.lightWarning}}
            <div class="wireframe-image-field__warning" role="status">
              {{dIcon "circle-exclamation"}}
              <span>{{i18n this.lightWarning}}</span>
            </div>
          {{/if}}

        </div>
      </ImageSource>

      {{#if this.allowDark}}
        <ImageSource
          class="wireframe-image-field__dark"
          @disabled={{@custom.disabled}}
          @label={{i18n
            (if
              this.darkVariant.url
              "wireframe.inspector.image.dark_label"
              "wireframe.inspector.image.add_dark"
            )
          }}
          @target={{hash
            blockKey=this.target.blockKey
            argName=this.target.argName
            variant="dark"
          }}
          @value={{this.darkVariant}}
        >
          <div class="wireframe-image-field__source-editor">
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
                      (eq this.darkTab "url")
                      "wireframe-image-field__tab--active"
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
                  class="wireframe-image-field__uploader"
                  @id="{{@custom.id}}-{{@custom.name}}-dark"
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
                  placeholder={{i18n
                    "wireframe.inspector.image.url_placeholder"
                  }}
                  value={{this.darkUrlDraft}}
                  {{on "input" this.onDarkUrlDraftInput}}
                  {{on "blur" this.commitDarkUrl}}
                />
              {{/if}}

              {{#if this.darkVariant.url}}
                <DButton
                  class="wireframe-image-field__remove btn-transparent btn-small --danger"
                  @icon="trash-can"
                  @label="wireframe.inspector.image.remove"
                  @action={{this.onDarkUploadDeleted}}
                />
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
          </div>
        </ImageSource>
      {{/if}}

      {{#if @schema.allowComposition}}
        {{#if this.lightVariant.url}}
          <ImageCompositionControls
            @target={{this.target}}
            @value={{this.liveValue}}
            @onReposition={{@onReposition}}
          />
        {{/if}}
      {{/if}}

      {{#if (and this.lightVariant.url this.gridOwnsSize)}}
        <fieldset class="wireframe-image-field__frame">
          <legend>{{i18n "wireframe.inspector.image.frame_size"}}</legend>
          <div class="wireframe-image-field__grid">
            <span>{{i18n "wireframe.inspector.image.grid_size"}}</span>
            <DButton
              class="btn-transparent btn-small"
              @title="wireframe.inspector.image.grid_size_help"
              @action={{this.editGrid}}
              @label="wireframe.inspector.image.edit_grid"
            />
          </div>
        </fieldset>
      {{else if this.allowFrameResize}}
        {{#if this.lightVariant.url}}
          <fieldset class="wireframe-image-field__frame">
            <legend>{{i18n "wireframe.inspector.image.frame_size"}}</legend>
            <label>{{i18n
                "wireframe.inspector.image.frame_width_short"
              }}<FKControlInput
                aria-label={{i18n "wireframe.inspector.image.frame_width"}}
                min="1"
                @type="number"
                @after="px"
                @field={{hash
                  hasExplicitType=true
                  value=this.frameSize.width
                  set=(noop)
                }}
                {{on "blur" (fn this.resizeFrame "width")}}
                {{on "keydown" (fn this.frameKeyDown "width")}}
              /></label>
            <label>{{i18n
                "wireframe.inspector.image.frame_height_short"
              }}<FKControlInput
                aria-label={{i18n "wireframe.inspector.image.frame_height"}}
                min="1"
                @type="number"
                @after="px"
                @field={{hash
                  hasExplicitType=true
                  value=this.frameSize.height
                  set=(noop)
                }}
                {{on "blur" (fn this.resizeFrame "height")}}
                {{on "keydown" (fn this.frameKeyDown "height")}}
              /></label>
            {{#if this.lightIsResized}}
              <DButton
                class="btn-transparent btn-small"
                @action={{this.resetLightSize}}
                @label="wireframe.inspector.image.reset_to_natural"
              />
            {{/if}}
          </fieldset>
        {{/if}}
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
