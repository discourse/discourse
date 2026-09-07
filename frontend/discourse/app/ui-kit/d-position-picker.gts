import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { type TrustedHTML, trustHTML } from "@ember/template";
import dPointerDrag, {
  type DPointerDragInfo,
} from "discourse/ui-kit/modifiers/d-pointer-drag";
import { i18n } from "discourse-i18n";

export interface PercentagePosition {
  /** Physical horizontal position, from the left edge (0) to the right (100). */
  x: number;
  /** Vertical position, from the top edge (0) to the bottom (100). */
  y: number;
}

interface DPositionPickerSignature {
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

export default class DPositionPicker extends Component<DPositionPickerSignature> {
  @tracked draft: PercentagePosition | null = null;
  #bounds: DOMRect | null = null;
  #pressedPreset: PercentagePosition | null = null;

  get position(): PercentagePosition {
    return this.draft ?? this.args.value;
  }

  get presets() {
    return [0, 50, 100].flatMap((y) =>
      [0, 50, 100].map((x) => ({
        x,
        y,
        label: i18n("position_picker.preset", { x, y }),
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
    this.draft = null;
    this.args.onCancel();
  }

  @action
  commit(): void {
    if (this.draft) {
      this.args.onChange(this.draft);
      this.draft = null;
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
    this.draft = null;
  }

  #preview(position: PercentagePosition): void {
    this.draft = position;
    this.args.onPreview(position);
  }

  <template>
    <div class="d-position-picker" ...attributes>
      <div
        class="d-position-picker__pad"
        tabindex="-1"
        role="group"
        aria-label={{i18n "position_picker.label"}}
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
            class="d-position-picker__preset"
            data-x={{preset.x}}
            data-y={{preset.y}}
            aria-label={{preset.label}}
            aria-pressed={{preset.selected}}
            {{on "click" (fn this.select preset)}}
          ><span></span></button>
        {{/each}}
        <span class="d-position-picker__thumb" style={{this.thumbStyle}}></span>
      </div>
      <div class="d-position-picker__coordinates">
        <label>{{i18n "position_picker.horizontal"}}<input
            type="number"
            min="0"
            max="100"
            step="1"
            value={{this.position.x}}
            {{on "input" (fn this.input "x")}}
            {{on "blur" this.commit}}
            {{on "keydown" this.keyDown}}
          /></label>
        <label>{{i18n "position_picker.vertical"}}<input
            type="number"
            min="0"
            max="100"
            step="1"
            value={{this.position.y}}
            {{on "input" (fn this.input "y")}}
            {{on "blur" this.commit}}
            {{on "keydown" this.keyDown}}
          /></label>
      </div>
    </div>
  </template>
}
