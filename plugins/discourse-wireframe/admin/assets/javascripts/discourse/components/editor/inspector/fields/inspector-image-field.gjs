// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import UppyImageUploader from "discourse/components/uppy-image-uploader";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const URL_PROBE_TIMEOUT_MS = 4000;
const ASPECT_RATIO_EPSILON = 0.02;

/**
 * Custom FormKit control for `type: "image"` args.
 *
 * Bypasses FormKit's draft entirely: reads the current value live from
 * `entry.args` via the wireframe service, and writes via
 * `wireframeImageUpload.setImageArg`. That keeps the inspector and the canvas
 * perfectly in
 * sync — paste / drop / click-to-pick mutations made on the canvas
 * show up immediately, and inspector edits land in the canvas with
 * the same code path as those external sources.
 *
 * Inline UX:
 *   - Upload | URL tabs at the top of the field.
 *   - Upload tab mounts `UppyImageUploader` directly so we can wrap
 *     the upload payload into our shape (`{source,url,width,height}`).
 *   - URL tab is a single text input; commit fires on blur. We probe
 *     the URL with `new Image()` to read intrinsic dimensions; a soft
 *     warning surfaces if the load fails or times out (the URL is
 *     still saved — the renderer just paints without intrinsic dims).
 *   - When `argDef.allowDark`, a collapsible "Dark variant" section
 *     repeats the same tabs for the dark sub-value.
 *   - A non-blocking ratio-mismatch warning shows when both variants
 *     carry intrinsic dimensions and their aspect ratios diverge
 *     beyond a small epsilon.
 *
 * @typedef {Object} ImageValue
 * @property {"upload"|"url"} [source]
 * @property {string} url
 * @property {number} [width]
 * @property {number} [height]
 * @property {ImageValue} [dark]
 */
export default class InspectorImageField extends Component {
  @service wireframeImageUpload;
  @service wireframeLayoutQuery;
  @service wireframeLayoutSignal;
  @service wireframeSelection;

  /**
   * URL-tab drafts per variant. Keep the field populated while the
   * user types so switching tabs and coming back doesn't blow away
   * their input. Committed to the saved value on blur.
   */
  @tracked lightUrlDraft = "";
  @tracked darkUrlDraft = "";

  /**
   * Tab state per variant. Defaults to the value's `source` when set;
   * falls back to `"upload"` for unset variants so the first
   * interaction is the file picker rather than a bare URL input.
   */
  @tracked lightTab = null;
  @tracked darkTab = null;

  /**
   * Soft warnings per variant (i18n keys). Cleared by the next
   * successful commit.
   */
  @tracked lightWarning = null;
  @tracked darkWarning = null;

  /**
   * In-flight URL probes (one per variant). Used internally to discard
   * stale probe resolutions when the user retypes — not touched from
   * the template.
   */
  #lightProbeToken = 0;
  #darkProbeToken = 0;

  constructor() {
    super(...arguments);
    const value = this.liveValue;
    this.lightTab = value?.source ?? "upload";
    this.lightUrlDraft = value?.source === "url" ? (value.url ?? "") : "";
    if (this.args.schema?.allowDark) {
      const dark = value?.dark;
      this.darkTab = dark?.source ?? "upload";
      this.darkUrlDraft = dark?.source === "url" ? (dark.url ?? "") : "";
    }
  }

  /* Live read from entry.args */

  /**
   * Selected block's key — the inspector only renders against the
   * current selection, so we always write to whatever's selected at
   * commit time.
   */
  get blockKey() {
    return this.wireframeSelection.selectedBlockKey;
  }

  /**
   * Arg name — FormKit's per-field wrapper carries `name` via
   * `@custom.name`. We don't read FormKit's draft value; we just use
   * its name as the arg key.
   */
  get argName() {
    return this.args.custom?.name;
  }

  /**
   * Live image-arg value off of `entry.args`. Reading via the
   * trackedObject opens a tracked dep, so any mutation — inspector
   * commit, paste, drop, replace menu — re-renders this field. Also
   * touches `wireframeLayoutSignal.version` so the entry lookup itself
   * re-evaluates after layout mutations (insert / move / replace).
   *
   * @returns {ImageValue|null}
   */
  get liveValue() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframeLayoutSignal.version;
    const key = this.blockKey;
    if (!key) {
      return null;
    }
    const entry = this.wireframeLayoutQuery.findEntryAndOutletSync(key)?.entry;
    return entry?.args?.[this.argName] ?? null;
  }

  /** @returns {ImageValue|null} */
  get lightVariant() {
    return this.liveValue;
  }

  /** @returns {ImageValue|null} */
  get darkVariant() {
    return this.liveValue?.dark ?? null;
  }

  get allowDark() {
    return this.args.schema?.allowDark === true;
  }

  /**
   * Returns the formatted warning when the dark variant's intrinsic
   * dimensions diverge from light beyond `ASPECT_RATIO_EPSILON`. The
   * renderer pins dark to light's frame via object-fit, so dark IS
   * actually clipped in this case — the warning is accurate.
   */
  @cached
  get ratioMismatchWarning() {
    const light = this.lightVariant;
    const dark = this.darkVariant;
    // Compare INTRINSIC (natural) ratios — the display width / height
    // get overridden when the user resizes via canvas drag handles,
    // so they no longer represent the source image's aspect.
    const lightW = light?.naturalWidth ?? light?.width;
    const lightH = light?.naturalHeight ?? light?.height;
    const darkW = dark?.naturalWidth ?? dark?.width;
    const darkH = dark?.naturalHeight ?? dark?.height;
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

  /* Write helpers (go through the wireframe service, not FormKit) */

  /**
   * Returns `true` when the light variant's display dims differ from
   * its natural ones — indicating the image has been resized.
   *
   * @returns {boolean}
   */
  get lightIsResized() {
    const v = this.lightVariant;
    if (!v?.naturalWidth || !v?.naturalHeight || !v?.width || !v?.height) {
      return false;
    }
    return v.width !== v.naturalWidth || v.height !== v.naturalHeight;
  }

  @action
  onLightUploadDone(upload) {
    this.lightTab = "upload";
    this.lightWarning = null;
    this.#commitLight(this.#uploadToVariant(upload));
  }

  @action
  onLightUploadDeleted() {
    this.lightWarning = null;
    this.#commitLight(null);
  }

  @action
  onDarkUploadDone(upload) {
    this.darkTab = "upload";
    this.darkWarning = null;
    this.#commitDark(this.#uploadToVariant(upload));
  }

  @action
  onDarkUploadDeleted() {
    this.darkWarning = null;
    this.#commitDark(null);
  }

  /* URL handlers (template-bound, so unprefixed) */

  @action
  setLightTab(tab) {
    this.lightTab = tab;
  }

  @action
  setDarkTab(tab) {
    this.darkTab = tab;
  }

  @action
  onLightUrlDraftInput(event) {
    this.lightUrlDraft = event.target.value;
  }

  @action
  onDarkUrlDraftInput(event) {
    this.darkUrlDraft = event.target.value;
  }

  @action
  commitLightUrl() {
    const url = this.lightUrlDraft.trim();
    if (!url) {
      return;
    }
    if (url === this.lightVariant?.url) {
      return;
    }
    const token = ++this.#lightProbeToken;
    probeUrl(url).then(({ width, height, failed }) => {
      if (token !== this.#lightProbeToken) {
        return;
      }
      this.lightWarning = failed
        ? "wireframe.inspector.image.url_probe_failed"
        : null;
      this.#commitLight({
        source: "url",
        url,
        width,
        height,
        naturalWidth: width,
        naturalHeight: height,
      });
    });
  }

  @action
  commitDarkUrl() {
    const url = this.darkUrlDraft.trim();
    if (!url) {
      return;
    }
    if (url === this.darkVariant?.url) {
      return;
    }
    const token = ++this.#darkProbeToken;
    probeUrl(url).then(({ width, height, failed }) => {
      if (token !== this.#darkProbeToken) {
        return;
      }
      this.darkWarning = failed
        ? "wireframe.inspector.image.url_probe_failed"
        : null;
      this.#commitDark({
        source: "url",
        url,
        width,
        height,
        naturalWidth: width,
        naturalHeight: height,
      });
    });
  }

  /**
   * Resets the light variant's display dimensions back to its
   * intrinsic / natural size. Wired to the "Reset to natural" link
   * shown when the user has resized via canvas drag handles.
   */
  @action
  resetLightSize() {
    const v = this.lightVariant;
    if (!v?.naturalWidth || !v?.naturalHeight) {
      return;
    }
    this.#commitLight({
      ...v,
      width: v.naturalWidth,
      height: v.naturalHeight,
    });
  }

  #commitLight(next) {
    if (!this.blockKey) {
      return;
    }
    if (next == null) {
      this.wireframeImageUpload.setImageArg(this.blockKey, this.argName, null);
      return;
    }
    const merged = { ...next };
    const existingDark = this.darkVariant;
    if (existingDark) {
      merged.dark = existingDark;
    }
    this.wireframeImageUpload.setImageArg(this.blockKey, this.argName, merged);
  }

  #commitDark(next) {
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

  #uploadToVariant(upload) {
    // `upload_id` is what lets server-side cleanup create an
    // UploadReference for this image; without it the upload is
    // treated as orphaned and gets deleted by Jobs::CleanUpUploads
    // after the 48h grace period.
    //
    // `width` / `height` are the DISPLAY dimensions (what the
    // renderer paints at); `naturalWidth` / `naturalHeight` are the
    // intrinsic dimensions captured at upload time. They diverge
    // when the user resizes via the canvas drag handles — the
    // inspector compares them to surface a "resized" info badge +
    // a "Reset to natural" affordance.
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

  /* Upload handlers (template-bound, so unprefixed) */

  <template>
    <div class="wireframe-image-field">
      <div class="wireframe-image-field__variant">
        <div class="wireframe-image-field__tabs" role="tablist">
          <button
            type="button"
            class="wireframe-image-field__tab
              {{if
                (eq this.lightTab 'upload')
                'wireframe-image-field__tab--active'
              }}"
            role="tab"
            aria-selected={{eq this.lightTab "upload"}}
            {{on "click" (fn this.setLightTab "upload")}}
          >
            {{i18n "wireframe.inspector.image.tab_upload"}}
          </button>
          <button
            type="button"
            class="wireframe-image-field__tab
              {{if
                (eq this.lightTab 'url')
                'wireframe-image-field__tab--active'
              }}"
            role="tab"
            aria-selected={{eq this.lightTab "url"}}
            {{on "click" (fn this.setLightTab "url")}}
          >
            {{i18n "wireframe.inspector.image.tab_url"}}
          </button>
        </div>

        {{#if (eq this.lightTab "upload")}}
          <UppyImageUploader
            @id="{{@custom.id}}-{{@custom.name}}-light"
            @imageUrl={{this.lightVariant.url}}
            @onUploadDone={{this.onLightUploadDone}}
            @onUploadDeleted={{this.onLightUploadDeleted}}
            @type="composer"
            class="wireframe-image-field__uploader no-repeat contain-image"
          />
        {{else}}
          <input
            type="url"
            class="wireframe-image-field__url-input"
            placeholder={{i18n "wireframe.inspector.image.url_placeholder"}}
            value={{this.lightUrlDraft}}
            {{on "input" this.onLightUrlDraftInput}}
            {{on "blur" this.commitLightUrl}}
          />
        {{/if}}

        {{#if this.lightWarning}}
          <div class="wireframe-image-field__warning" role="status">
            {{dIcon "circle-exclamation"}}
            <span>{{i18n this.lightWarning}}</span>
          </div>
        {{/if}}

        {{#if this.lightIsResized}}
          {{! Informational note (not a warning) when the user has
            resized via canvas drag handles. Shows the current
            display dims vs the natural dims and offers a one-click
            reset. }}
          <div class="wireframe-image-field__info" role="status">
            {{dIcon "info-circle"}}
            <span>
              {{i18n
                "wireframe.inspector.image.resized_info"
                width=this.lightVariant.width
                height=this.lightVariant.height
                natural_width=this.lightVariant.naturalWidth
                natural_height=this.lightVariant.naturalHeight
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

      {{#if this.allowDark}}
        <details class="wireframe-image-field__dark" open={{this.darkVariant}}>
          <summary>{{i18n "wireframe.inspector.image.dark_label"}}</summary>
          <p class="wireframe-image-field__dark-help">
            {{i18n "wireframe.inspector.image.dark_help"}}
          </p>

          {{#if this.lightVariant.url}}
            <div class="wireframe-image-field__tabs" role="tablist">
              <button
                type="button"
                class="wireframe-image-field__tab
                  {{if
                    (eq this.darkTab 'upload')
                    'wireframe-image-field__tab--active'
                  }}"
                role="tab"
                aria-selected={{eq this.darkTab "upload"}}
                {{on "click" (fn this.setDarkTab "upload")}}
              >
                {{i18n "wireframe.inspector.image.tab_upload"}}
              </button>
              <button
                type="button"
                class="wireframe-image-field__tab
                  {{if
                    (eq this.darkTab 'url')
                    'wireframe-image-field__tab--active'
                  }}"
                role="tab"
                aria-selected={{eq this.darkTab "url"}}
                {{on "click" (fn this.setDarkTab "url")}}
              >
                {{i18n "wireframe.inspector.image.tab_url"}}
              </button>
            </div>

            {{#if (eq this.darkTab "upload")}}
              <UppyImageUploader
                @id="{{@custom.id}}-{{@custom.name}}-dark"
                @imageUrl={{this.darkVariant.url}}
                @onUploadDone={{this.onDarkUploadDone}}
                @onUploadDeleted={{this.onDarkUploadDeleted}}
                @type="composer"
                class="wireframe-image-field__uploader no-repeat contain-image"
              />
            {{else}}
              <input
                type="url"
                class="wireframe-image-field__url-input"
                placeholder={{i18n "wireframe.inspector.image.url_placeholder"}}
                value={{this.darkUrlDraft}}
                {{on "input" this.onDarkUrlDraftInput}}
                {{on "blur" this.commitDarkUrl}}
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
 * @param {string} url
 * @returns {Promise<{width?: number, height?: number, failed: boolean}>}
 */
function probeUrl(url) {
  return new Promise((resolve) => {
    const img = new Image();
    let settled = false;
    const finish = (result) => {
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
