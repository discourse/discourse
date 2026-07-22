import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { type ComponentLike } from "@glint/template";
import DIconGridPickerContentUntyped from "discourse/ui-kit/d-icon-grid-picker/content";

// TODO(devxp-typescript-pending): drop the cast once
// `d-icon-grid-picker/content` is authored in .gts with a real Signature, then
// import it directly. An untyped .gjs today gives Glint no arg/attribute types,
// so passing `@value` / `@onSelect` would otherwise error. We describe only the
// two args consumed here.
const DIconGridPickerContent =
  DIconGridPickerContentUntyped as unknown as ComponentLike<{
    /** Current value and selection callback. */
    Args: {
      /** Currently selected icon ID. */
      value?: string;
      /** Handles icon selection. */
      onSelect?: (
        /** Selected icon ID. */
        iconId: string
      ) => void;
    };
  }>;

/**
 * The payload the FloatKit menu service injects as `@data` when this component
 * is opened via `menu.show(anchorEl, { component: this, data: { value,
 * onSelect } })`. See `WireframeInplaceIconService`.
 */
type InplaceIconPopoverData = {
  /** The currently selected icon ID, used to preselect the grid. */
  value?: string;
  /** Called with the chosen icon ID when the user picks one. */
  onSelect?: (
    /** Selected icon ID. */
    iconId: string
  ) => void;
};

interface InplaceIconPopoverSignature {
  /** FloatKit data supplied when the popover opens. */
  Args: {
    /** Current icon value and selection callback. */
    data: InplaceIconPopoverData;
  };
}

/**
 * Popover content shown when the user clicks an in-place-editable icon
 * on the canvas. Renders the standalone `DIconGridPickerContent`
 * (the same grid+search UI used by the FormKit `icon` control) and
 * commits the selection via `@data.onSelect`.
 *
 * `@data` is provided by the FloatKit menu service when this
 * component is opened via `menu.show(anchorEl, { component: this,
 * data: { value, onSelect } })`.
 */
const InplaceIconPopover: TemplateOnlyComponent<InplaceIconPopoverSignature> =
  <template>
    <DIconGridPickerContent
      @value={{@data.value}}
      @onSelect={{@data.onSelect}}
    />
  </template>;

export default InplaceIconPopover;
