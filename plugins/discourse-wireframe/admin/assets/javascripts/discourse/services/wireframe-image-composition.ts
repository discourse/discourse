import { tracked } from "@glimmer/tracking";
import type Owner from "@ember/owner";
import Service, { service } from "@ember/service";
import {
  type BlockImageValue,
  type ImageComposition,
  imageComposition,
} from "discourse/blocks/image-value";
import { isImageArgValue } from "discourse/plugins/discourse-wireframe/discourse/lib/empty-image-upload";
import type WireframeLayoutQueryService from "./wireframe-layout-query";
import type WireframeMutationEngineService from "./wireframe-mutation-engine";
import type WireframeSelectionService from "./wireframe-selection";

export interface ImageEditTarget {
  /** Stable block identity, captured before starting an interaction. */
  blockKey: string;
  /** Image argument on that block. */
  argName: string;
}

export default class WireframeImageCompositionService extends Service {
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;
  @service declare wireframeMutationEngine: WireframeMutationEngineService;
  @service declare wireframeSelection: WireframeSelectionService;

  @tracked draft: ImageComposition | null = null;
  @tracked repositioning = false;
  @tracked target: ImageEditTarget | null = null;

  #focus: HTMLElement | null = null;
  #frame: HTMLElement | null = null;
  #original: BlockImageValue | null = null;
  #reference: unknown;
  #styles = new Map<string, string>();

  constructor(owner: Owner) {
    super(owner);
    this.wireframeMutationEngine.registerBeforeHistoryChange(() =>
      this.cancel()
    );
    this.wireframeSelection.registerBeforeChange(({ nextKey }) => {
      if (this.target && nextKey !== this.target.blockKey) {
        // Leave focus with the incoming selection instead of the old trigger.
        this.#focus = null;
        this.commit();
      }
    });
  }

  willDestroy(): void {
    this.cancel();
    super.willDestroy();
  }

  begin(target: ImageEditTarget, repositioning = false): boolean {
    if (this.matches(target)) {
      this.repositioning ||= repositioning;
      return true;
    }
    this.cancel();
    const value = this.wireframeLayoutQuery.findEntryAndOutletSync(
      target.blockKey
    )?.entry.args?.[target.argName];
    if (!isImageArgValue(value) || !value.url) {
      return false;
    }
    this.#reference = value;
    this.#original = JSON.parse(JSON.stringify(value)) as BlockImageValue;
    this.target = { ...target };
    this.draft = imageComposition(this.#original);
    this.repositioning = repositioning;
    this.#focus =
      document.activeElement instanceof HTMLElement
        ? document.activeElement
        : null;
    const chrome = document.querySelector(
      `[data-wf-block-key="${CSS.escape(target.blockKey)}"]`
    );
    const marker = chrome?.querySelector<HTMLElement>(
      `[data-block-arg="${CSS.escape(target.argName)}"]`
    );
    this.#frame = marker?.matches(".d-block-image-frame")
      ? marker
      : (marker?.querySelector<HTMLElement>(".d-block-image-frame") ?? null);
    if (this.#frame) {
      for (const property of [
        "--block-image-fit",
        "--block-image-position",
        "--block-image-zoom",
      ]) {
        this.#styles.set(
          property,
          this.#frame.style.getPropertyValue(property)
        );
      }
    }
    return true;
  }

  cancel(): void {
    for (const [property, value] of this.#styles) {
      if (value) {
        this.#frame?.style.setProperty(property, value);
      } else {
        this.#frame?.style.removeProperty(property);
      }
    }
    if (this.repositioning && this.#focus?.isConnected) {
      this.#focus.focus();
    }
    this.#styles.clear();
    this.#frame = null;
    this.#focus = null;
    this.#original = null;
    this.#reference = undefined;
    this.target = null;
    this.draft = null;
    this.repositioning = false;
  }

  change(target: ImageEditTarget, patch: Partial<ImageComposition>): void {
    this.preview(target, patch);
    if (!this.repositioning) {
      this.commit();
    }
  }

  commit(): void {
    const target = this.target;
    const located =
      target &&
      this.wireframeLayoutQuery.findEntryAndOutletSync(target.blockKey);
    if (
      JSON.stringify(this.draft) ===
      JSON.stringify(imageComposition(this.#original))
    ) {
      this.cancel();
      return;
    }
    if (
      target &&
      located &&
      this.draft &&
      located.entry.args?.[target.argName] === this.#reference
    ) {
      const nextValue = { ...this.#original, ...this.draft };
      const prevValue = this.#original;
      this.cancel();
      this.wireframeMutationEngine.recordArgEdit({
        ...located,
        argName: target.argName,
        prevValue,
        nextValue,
      });
    } else {
      this.cancel();
    }
  }

  matches(target: ImageEditTarget | null): boolean {
    return (
      !!target &&
      this.target?.blockKey === target.blockKey &&
      this.target.argName === target.argName
    );
  }

  preview(target: ImageEditTarget, patch: Partial<ImageComposition>): void {
    if (!this.begin(target)) {
      return;
    }
    this.draft = imageComposition({ ...this.draft, ...patch });
    const { fit, position, zoom } = this.draft;
    this.#frame?.style.setProperty("--block-image-fit", fit);
    this.#frame?.style.setProperty(
      "--block-image-position",
      `${position.x}% ${position.y}%`
    );
    this.#frame?.style.setProperty("--block-image-zoom", String(zoom / 100));
  }
}
