import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type { ComponentLike } from "@glint/template";
import FKControlInputUntyped from "discourse/form-kit/components/fk/control/input";
import noop from "discourse/helpers/noop";
import { i18n } from "discourse-i18n";

/** TODO(devxp-typescript-pending): remove when the input exports a signature. */
const FKControlInput = FKControlInputUntyped as unknown as ComponentLike<{
  Args: {
    type: "number";
    before: string;
    after: string;
    field: { hasExplicitType: boolean; value: number; set: () => void };
  };
  Element: HTMLInputElement;
}>;

export interface PercentagePosition {
  /** Physical horizontal position, from the left edge (0) to the right (100). */
  x: number;
  /** Vertical position, from the top edge (0) to the bottom (100). */
  y: number;
}

interface ImagePositionPickerSignature {
  Args: {
    /** Current percentage position. */
    value: PercentagePosition;
    /** Receives temporary pointer and numeric edits, without creating history. */
    onPreview: (value: PercentagePosition) => void;
    /** Receives one committed position per completed interaction. */
    onChange: (value: PercentagePosition) => void;
    /** Discards the current interaction's preview. */
    onCancel: () => void;
  };
  Element: HTMLDivElement;
}

export default class ImagePositionPicker extends Component<ImagePositionPickerSignature> {
  @tracked _draft: PercentagePosition | null = null;

  get position(): PercentagePosition {
    return this._draft ?? this.args.value;
  }

  @action
  cancel(): void {
    this._draft = null;
    this.args.onCancel();
  }

  @action
  commit(): void {
    if (this._draft) {
      this.args.onChange(this._draft);
      this._draft = null;
    }
  }

  @action
  input(axis: "x" | "y", event: Event): void {
    const input = event.currentTarget;
    if (
      !(input instanceof HTMLInputElement) ||
      !Number.isFinite(input.valueAsNumber)
    ) {
      return;
    }
    this.#preview({
      ...this.position,
      [axis]: Math.min(100, Math.max(0, input.valueAsNumber)),
    });
  }

  @action
  keyDown(event: KeyboardEvent): void {
    if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      this.cancel();
    } else if (event.key === "Enter") {
      event.preventDefault();
      this.commit();
    }
  }

  #preview(position: PercentagePosition): void {
    this._draft = position;
    this.args.onPreview(position);
  }

  <template>
    <div class="wireframe-image-position-picker" ...attributes>
      <div>
        {{! Native events retain the preview and commit boundaries. }}
        <FKControlInput
          aria-label={{i18n "wireframe.position_picker.horizontal"}}
          max="100"
          min="0"
          step="1"
          @after="%"
          @before={{i18n "wireframe.position_picker.horizontal_short"}}
          @field={{hash hasExplicitType=true value=this.position.x set=(noop)}}
          @type="number"
          {{on "input" (fn this.input "x")}}
          {{on "blur" this.commit}}
          {{on "keydown" this.keyDown}}
        />
      </div>
      <div>
        <FKControlInput
          aria-label={{i18n "wireframe.position_picker.vertical"}}
          max="100"
          min="0"
          step="1"
          @after="%"
          @before={{i18n "wireframe.position_picker.vertical_short"}}
          @field={{hash hasExplicitType=true value=this.position.y set=(noop)}}
          @type="number"
          {{on "input" (fn this.input "y")}}
          {{on "blur" this.commit}}
          {{on "keydown" this.keyDown}}
        />
      </div>
    </div>
  </template>
}
