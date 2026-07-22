import Component from "@glimmer/component";
import { action } from "@ember/object";
import { type ComponentLike } from "@glint/template";
import DSegmentedControlUntyped from "discourse/components/d-segmented-control";
import ComboBoxUntyped from "discourse/select-kit/components/combo-box";
import DFitSwap from "discourse/ui-kit/d-fit-swap";

// The most options a segmented row is allowed to show regardless of width. Even
// with room, past this many segments the row is too busy to scan, so we always
// fall back to a dropdown.
const SEGMENT_MAX = 6;

/**
 * A single choosable option, either supplied pre-built via `@items` or derived
 * from `@options` + `@optionIcons`. The label doubles as the tooltip and the
 * dropdown-fallback text; the icon renders instead of the label when present.
 */
type SegmentedItem = {
  /** Persisted option value. */
  value: string;
  /** Visible option label. */
  label?: string;
  /** Optional icon replacing the visible label. */
  icon?: string;
  /** Accessible tooltip text. */
  title?: string;
};

/**
 * The subset of a FormKit field's yielded data this component reads when driven
 * through the generic form. FormKit is untyped upstream, so we describe only the
 * members consumed here rather than depend on a non-existent exported type.
 */
type InspectorFieldData = {
  /** Current FormKit field value. */
  value: unknown;
  /** Optional FormKit field name. */
  name?: string;
  /** Writes a replacement FormKit field value. */
  set: (
    /** Replacement field value. */
    value: unknown
  ) => void;
};

interface InspectorSegmentedFieldSignature {
  /** Option data and FormKit or standalone value integration. */
  Args: {
    /** FormKit field data (generic form). Reads `value`/`name`, writes `set`. */
    custom?: InspectorFieldData;
    /** Current value (standalone form). */
    value?: unknown;
    /** Change handler (standalone form). */
    onChange?: (
      /** Newly selected option value. */
      value: string
    ) => void;
    /** Radio group name for the segmented control. */
    name?: string;
    /** Pre-built option rows (the layout form supplies axis-aware icons). */
    items?: SegmentedItem[];
    /** Raw option values; the value doubles as its own label and tooltip. */
    options?: string[] | null;
    /** Optional icon per option value, used with `@options`. */
    optionIcons?: Record<string, string> | null;
  };
  /** Root segmented control or dropdown element. */
  Element: HTMLElement;
}

/**
 * `ComboBox` is an untyped select-kit `.gjs` component (no Glint `Signature`),
 * so invoking it from this `.gts` has no arg/attribute types. Describe the shape
 * we use at the boundary.
 *
 * TODO(devxp-typescript-pending): drop this cast once `ComboBox` is authored in
 * `.gts` with a real `Signature`, then import it directly.
 */
const ComboBox = ComboBoxUntyped as unknown as ComponentLike<{
  /** Select-kit content and value configuration. */
  Args: {
    /** Options displayed by the dropdown. */
    content: SegmentedItem[];
    /** Currently selected option value. */
    value: unknown;
    /** Property used as the visible option label. */
    nameProperty: string;
    /** Property used as the persisted option value. */
    valueProperty: string;
    /** Handles selection changes. */
    onChange: (
      /** Newly selected option value. */
      value: string
    ) => void;
  };
  /** Root select-kit element. */
  Element: HTMLElement;
}>;

/**
 * `DSegmentedControl` is an untyped `.gjs` component (no Glint `Signature`), so
 * invoking it from this `.gts` has no arg/attribute types. Describe the shape we
 * use at the boundary.
 *
 * TODO(devxp-typescript-pending): drop this cast once `DSegmentedControl` is
 * authored in `.gts` with a real `Signature`, then import it directly.
 */
const DSegmentedControl = DSegmentedControlUntyped as unknown as ComponentLike<{
  /** Segmented-control options and selection behavior. */
  Args: {
    /** Options displayed by the control. */
    items: SegmentedItem[];
    /** Currently selected option value. */
    value: unknown;
    /** Optional radio-group name. */
    name?: string;
    /** Handles option selection. */
    onSelect: (
      /** Newly selected option value. */
      value: string
    ) => void;
  };
  /** Root segmented-control element. */
  Element: HTMLElement;
}>;

/**
 * The inspector's one enum picker. Renders a single-select choice as a segmented
 * control — each option shows its icon when it has one, otherwise its label (so
 * a mixed set like "Auto" + alignment arrows reads naturally) — and folds to a
 * dropdown when the row would be cramped.
 *
 * The fold is width-driven through the core `DFitSwap` component: the segmented
 * row collapses to the dropdown whenever its natural width no longer fits the
 * field (drag the inspector rail narrow and it folds; widen it and the segments
 * return). `SEGMENT_MAX` remains a hard cap independent of width.
 *
 * Both `DSegmentedControl` and `ComboBox` carry their own keyboard / screen-reader
 * behavior; folding only swaps which one renders.
 *
 * Two ways to drive it:
 *   - **Generic form (FormKit custom slot):** pass `@custom` (the yielded
 *     FieldData). Reads `@custom.value`, writes `@custom.set`.
 *   - **Standalone:** pass `@value` + `@onChange` (the bespoke layout form).
 *
 * Items come either pre-built via `@items` (`{value, label, icon?, title?}` — the
 * layout form supplies axis-aware icons) or from `@options` + the optional
 * `@optionIcons` map (the generic form), in which case the value doubles as the
 * label and tooltip.
 */
export default class InspectorSegmentedField extends Component<InspectorSegmentedFieldSignature> {
  /** Current value from the active FormKit or standalone source. */
  get currentValue(): unknown {
    return this.args.custom ? this.args.custom.value : this.args.value;
  }

  /** Effective radio-group name. */
  get name(): string | undefined {
    return this.args.name ?? this.args.custom?.name;
  }

  /** Normalized `{value, label, icon, title}` rows. */
  get items(): SegmentedItem[] {
    if (this.args.items) {
      return this.args.items.map((item) => ({
        ...item,
        title: item.title ?? item.label,
      }));
    }
    const options = this.args.options ?? [];
    const icons = this.args.optionIcons ?? {};
    return options.map((value) => ({
      value,
      label: value,
      icon: icons[value],
      title: value,
    }));
  }

  /**
   * `true` when there are too many options for a segmented row no matter how
   * wide the field is; width-driven folding is handled by `DFitSwap` instead.
   */
  get exceedsSegmentMax(): boolean {
    return this.items.length > SEGMENT_MAX;
  }

  /**
   * Items for `DSegmentedControl`. Drop the label on any option that has an icon
   * so iconned options render icon-only while icon-less ones keep their text — a
   * per-option choice, not all-or-nothing.
   */
  get segmentItems(): SegmentedItem[] {
    return this.items.map((item) => ({
      value: item.value,
      label: item.icon ? undefined : item.label,
      icon: item.icon,
      title: item.title,
    }));
  }

  @action
  commit(value: string): void {
    if (this.args.custom) {
      this.args.custom.set(value);
    } else {
      this.args.onChange?.(value);
    }
  }

  <template>
    {{#if this.exceedsSegmentMax}}
      <ComboBox
        class="wireframe-segmented-field__dropdown"
        @content={{this.items}}
        @value={{this.currentValue}}
        @nameProperty="label"
        @valueProperty="value"
        @onChange={{this.commit}}
      />
    {{else}}
      <DFitSwap @remeasureOn={{this.items}}>
        <:full>
          <DSegmentedControl
            class="wireframe-segmented-field"
            @items={{this.segmentItems}}
            @value={{this.currentValue}}
            @name={{this.name}}
            @onSelect={{this.commit}}
          />
        </:full>
        <:collapsed>
          <ComboBox
            class="wireframe-segmented-field__dropdown"
            @content={{this.items}}
            @value={{this.currentValue}}
            @nameProperty="label"
            @valueProperty="value"
            @onChange={{this.commit}}
          />
        </:collapsed>
      </DFitSwap>
    {{/if}}
  </template>
}
