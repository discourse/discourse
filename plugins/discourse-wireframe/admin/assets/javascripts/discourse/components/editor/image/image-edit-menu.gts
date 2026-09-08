import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import type { ArgSchema } from "discourse/blocks/types";
import TrackedMediaQuery from "discourse/lib/tracked-media-query";
import type Session from "discourse/models/session";
import type InterfaceColorService from "discourse/services/interface-color";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import ImageCompositionControls from "discourse/plugins/discourse-wireframe/discourse/components/editor/image/image-composition-controls";
import { isImageArgValue } from "discourse/plugins/discourse-wireframe/discourse/lib/empty-image-upload";
import type WireframeImageUploadService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-image-upload";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeLayoutSignalService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-signal";
import type WireframeRailService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-rail";
import type WireframeSelectionService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

export type ImageEditMenuData = {
  /** Stable destination for image edits. */
  blockKey: string;
  /** Image argument on that block. */
  argName: string;
  /** Capabilities exposed by the image's block. */
  schema?: ArgSchema;
  /** Closes the owning FloatKit menu. */
  close: () => Promise<void>;
};

interface ImageEditMenuSignature {
  Args: {
    /** Destination and capabilities provided by the canvas. */
    data: ImageEditMenuData;
  };
}

export default class ImageEditMenu extends Component<ImageEditMenuSignature> {
  @service declare interfaceColor: InterfaceColorService;

  /** TODO(typescript-pending): remove the extension when Session types its bootstrap color fields. */
  @service
  declare session: Session & {
    /** The default theme palette is dark, without requiring a media query. */
    defaultColorSchemeIsDark: boolean;
    /** The theme offers a separate dark palette. */
    darkModeAvailable: boolean;
  };

  @service declare wireframeImageUpload: WireframeImageUploadService;
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;
  @service declare wireframeRail: WireframeRailService;
  @service declare wireframeSelection: WireframeSelectionService;

  @tracked uploadFailed = false;
  @tracked uploading = false;

  #darkFileInput: HTMLInputElement | null = null;
  #darkMedia = new TrackedMediaQuery("(prefers-color-scheme: dark)");
  #fileInput: HTMLInputElement | null = null;

  willDestroy(): void {
    this.#darkMedia.teardown();
    super.willDestroy();
  }

  get canAddDarkVariant(): boolean {
    return Boolean(
      this.args.data.schema?.allowDark &&
      this.value?.url &&
      !this.hasDarkVariant
    );
  }

  get changeLabel(): string {
    if (this.hasDarkVariant) {
      return this.#isDarkMode
        ? "wireframe.inspector.image.change_dark"
        : "wireframe.inspector.image.change_light";
    }
    return this.#isDefaultFallback
      ? "wireframe.inspector.image.change_default"
      : "wireframe.inspector.image.change";
  }

  get hasDarkVariant(): boolean {
    return Boolean(this.value?.dark?.url);
  }

  get #isDarkMode(): boolean {
    return Boolean(
      this.session.defaultColorSchemeIsDark ||
      (this.session.darkModeAvailable &&
        (this.interfaceColor.darkModeForced ||
          (!this.interfaceColor.lightModeForced && this.#darkMedia.matches)))
    );
  }

  get #isDefaultFallback(): boolean {
    return this.#isDarkMode && this.canAddDarkVariant;
  }

  get showInspectorShortcut(): boolean {
    if (
      this.wireframeRail.rightCollapsed ||
      this.wireframeRail.inspectorTab !== "args"
    ) {
      return true;
    }
    const { blockKey, argName } = this.args.data;
    const field = document.querySelector<HTMLElement>(
      `.wireframe-panel.--right .wireframe-image-field[data-block-key="${CSS.escape(blockKey)}"][data-image-arg="${CSS.escape(argName)}"]`
    );
    const panel = field?.closest(".wireframe-panel.--right");
    const source =
      this.visibleVariant === "dark"
        ? field?.querySelector<HTMLDetailsElement>(
            ".wireframe-image-field__dark"
          )
        : field;
    if (source instanceof HTMLDetailsElement && !source.open) {
      return true;
    }
    const tabs = source?.querySelector(".d-tabs__tablist");
    if (!panel || !tabs) {
      return true;
    }
    const bounds = tabs.getBoundingClientRect();
    const panelBounds = panel.getBoundingClientRect();
    return (
      bounds.top < Math.max(panelBounds.top, 0) ||
      bounds.bottom > Math.min(panelBounds.bottom, window.innerHeight)
    );
  }

  get value() {
    void this.wireframeLayoutSignal.version;
    const value = this.wireframeLayoutQuery.findEntryAndOutletSync(
      this.args.data.blockKey
    )?.entry.args?.[this.args.data.argName];
    return isImageArgValue(value) ? value : null;
  }

  get visibleVariant(): "light" | "dark" {
    return this.#isDarkMode && this.hasDarkVariant ? "dark" : "light";
  }

  @action
  async moreSettings(): Promise<void> {
    const { blockKey, argName, close } = this.args.data;
    const selection = this.wireframeSelection;
    const rail = this.wireframeRail;
    const imageVariant = this.visibleVariant;
    await close();
    selection.selectBlock({ key: blockKey });
    rail.showInspector({ blockKey, argName, imageVariant });
  }

  @action
  pickDarkFile(): void {
    this.#darkFileInput?.click();
  }

  @action
  pickFile(): void {
    this.#fileInput?.click();
  }

  @action
  registerDarkFileInput(element: HTMLInputElement): void {
    this.#darkFileInput = element;
  }

  @action
  registerFileInput(element: HTMLInputElement): void {
    this.#fileInput = element;
  }

  @action
  async replace(variant: "light" | "dark", event: Event): Promise<void> {
    const input = event.currentTarget;
    if (!(input instanceof HTMLInputElement) || !input.files?.[0]) {
      return;
    }
    const file = input.files[0];
    input.value = "";
    this.uploading = true;
    this.uploadFailed = false;
    try {
      const result = await this.wireframeImageUpload.uploadImageForArg(file, {
        ...this.args.data,
        variant,
      });
      if (!this.isDestroyed) {
        this.uploadFailed = !result;
      }
    } catch {
      if (!this.isDestroyed) {
        this.uploadFailed = true;
      }
    } finally {
      if (!this.isDestroyed) {
        this.uploading = false;
      }
    }
  }

  <template>
    <div class="wireframe-image-editor-menu">
      {{#if @data.schema.allowComposition}}
        {{#if this.value}}
          <ImageCompositionControls
            @compact={{true}}
            @onReposition={{@data.close}}
            @target={{@data}}
            @value={{this.value}}
          />
          {{#if this.hasDarkVariant}}
            <p class="wireframe-image-editor-menu__hint">
              {{i18n "wireframe.inspector.image.shared_composition"}}
            </p>
          {{/if}}
          <hr class="wireframe-image-editor-menu__separator" />
        {{/if}}
      {{/if}}
      <DButton
        class="wireframe-image-editor-menu__action"
        @action={{this.pickFile}}
        @disabled={{this.uploading}}
        @isLoading={{this.uploading}}
        @label={{this.changeLabel}}
      />
      <input
        accept="image/*"
        hidden
        id="wireframe-image-upload-current"
        type="file"
        {{didInsert this.registerFileInput}}
        {{on "change" (fn this.replace this.visibleVariant)}}
      />
      {{#if this.canAddDarkVariant}}
        <DButton
          class="wireframe-image-editor-menu__action"
          @action={{this.pickDarkFile}}
          @disabled={{this.uploading}}
          @label="wireframe.inspector.image.add_dark"
        />
        <input
          accept="image/*"
          hidden
          id="wireframe-image-upload-dark"
          type="file"
          {{didInsert this.registerDarkFileInput}}
          {{on "change" (fn this.replace "dark")}}
        />
      {{/if}}
      {{#if this.uploadFailed}}
        <p class="wireframe-image-editor-menu__error" role="alert">
          {{i18n "wireframe.inspector.image.change_failed"}}
        </p>
      {{/if}}
      {{#if this.showInspectorShortcut}}
        <hr class="wireframe-image-editor-menu__separator" />
        <DButton
          class="wireframe-image-editor-menu__action wireframe-image-editor-menu__footer"
          @action={{this.moreSettings}}
          @label="wireframe.inspector.image.more_settings"
        />
      {{/if}}
    </div>
  </template>
}
