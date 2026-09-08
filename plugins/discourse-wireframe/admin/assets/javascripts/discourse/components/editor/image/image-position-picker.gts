import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { type TrustedHTML, trustHTML } from "@ember/template";
import type { ComponentLike } from "@glint/template";
import FKControlInputUntyped from "discourse/form-kit/components/fk/control/input";
import noop from "discourse/helpers/noop";
import dPointerDrag, {
  type DPointerDragInfo,
} from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";

/** TODO(devxp-typescript-pending): remove when the input exports a signature. */
const FKControlInput = FKControlInputUntyped as unknown as ComponentLike<{
  Args: {
    type: "number";
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
  #bounds: DOMRect | null = null;
  #pressedPreset: PercentagePosition | null = null;
  @tracked _draft: PercentagePosition | null = null;

  get position(): PercentagePosition {
    return this._draft ?? this.args.value;
  }

  get presets() {
    return [0, 50, 100].flatMap((y) =>
      [0, 50, 100].map((x) => ({
        x,
        y,
        label: i18n("wireframe.position_picker.preset", { x, y }),
        selected: this.position.x === x && this.position.y === y,
      }))
    );
  }

  get thumbStyle(): TrustedHTML {
    return trustHTML(
      `--position-x: ${this.position.x}%; --position-y: ${this.position.y}%;`
    );
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
  drag(_event: PointerEvent, info: DPointerDragInfo): void {
    const bounds = this.#bounds;
    if (bounds) {
      this.#preview({
        x: Math.round(
          Math.min(
            100,
            Math.max(0, ((info.current.x - bounds.left) / bounds.width) * 100)
          )
        ),
        y: Math.round(
          Math.min(
            100,
            Math.max(0, ((info.current.y - bounds.top) / bounds.height) * 100)
          )
        ),
      });
    }
  }

  @action
  dragEnd(event: PointerEvent, info: DPointerDragInfo): void {
    if (!info.moved && this.#pressedPreset) {
      this.#preview(this.#pressedPreset);
    } else {
      this.drag(event, info);
    }
    this.commit();
    this.#bounds = null;
    this.#pressedPreset = null;
  }

  @action
  dragStart(event: PointerEvent): boolean {
    if (!(event.currentTarget instanceof HTMLElement)) {
      return false;
    }
    event.currentTarget.focus();
    const preset =
      event.target instanceof Element
        ? event.target.closest<HTMLButtonElement>("button[data-x]")
        : null;
    this.#pressedPreset = preset
      ? { x: Number(preset.dataset.x), y: Number(preset.dataset.y) }
      : null;
    this.#bounds = event.currentTarget.getBoundingClientRect();
    return this.#bounds.width > 0 && this.#bounds.height > 0;
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

  @action
  select(position: PercentagePosition, event: MouseEvent): void {
    if (event.detail !== 0) {
      return;
    }
    this.args.onChange({ x: position.x, y: position.y });
    this._draft = null;
  }

  #preview(position: PercentagePosition): void {
    this._draft = position;
    this.args.onPreview(position);
  }

  <template>
    <div class="wireframe-image-position-picker" ...attributes>
      <div class="wireframe-image-position-picker__coordinates">
        {{! Native events retain the preview and commit boundaries. }}
        <label>
          <span class="wireframe-image-position-picker__axis">{{i18n
              "wireframe.position_picker.horizontal_short"
            }}</span>
          <FKControlInput
            aria-label={{i18n "wireframe.position_picker.horizontal"}}
            min="0"
            max="100"
            step="1"
            @after="%"
            @field={{hash
              hasExplicitType=true
              value=this.position.x
              set=(noop)
            }}
            @type="number"
            {{on "input" (fn this.input "x")}}
            {{on "blur" this.commit}}
            {{on "keydown" this.keyDown}}
          />
        </label>
        <label>
          <span class="wireframe-image-position-picker__axis">{{i18n
              "wireframe.position_picker.vertical_short"
            }}</span>
          <FKControlInput
            aria-label={{i18n "wireframe.position_picker.vertical"}}
            min="0"
            max="100"
            step="1"
            @after="%"
            @field={{hash
              hasExplicitType=true
              value=this.position.y
              set=(noop)
            }}
            @type="number"
            {{on "input" (fn this.input "y")}}
            {{on "blur" this.commit}}
            {{on "keydown" this.keyDown}}
          />
        </label>
      </div>
      <div
        class="wireframe-image-position-picker__pad"
        tabindex="-1"
        role="group"
        aria-label={{i18n "wireframe.position_picker.label"}}
        {{dPointerDrag
          onDragStart=this.dragStart
          onDrag=this.drag
          onDragEnd=this.dragEnd
          onDragCancel=this.cancel
        }}
      >
        {{#each this.presets as |preset|}}
          <button
            type="button"
            class="wireframe-image-position-picker__preset"
            data-x={{preset.x}}
            data-y={{preset.y}}
            aria-label={{preset.label}}
            aria-pressed={{preset.selected}}
            {{on "click" (fn this.select preset)}}
          ></button>
        {{/each}}
        <span
          class="wireframe-image-position-picker__thumb"
          style={{this.thumbStyle}}
        ></span>
      </div>
    </div>
  </template>
}
