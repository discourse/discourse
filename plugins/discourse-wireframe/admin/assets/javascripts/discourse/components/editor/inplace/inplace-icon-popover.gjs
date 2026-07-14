// @ts-check
import DIconGridPickerContent from "discourse/ui-kit/d-icon-grid-picker/content";

/**
 * Popover content shown when the user clicks an in-place-editable icon
 * on the canvas. Renders the standalone `DIconGridPickerContent`
 * (the same grid+search UI used by the FormKit `icon` control) and
 * commits the selection via `@data.onSelect`.
 *
 * `@data` is provided by the FloatKit menu service when this
 * component is opened via `menu.show(anchorEl, { content: this,
 * data: { value, onSelect } })`. See `IconEditState` in
 * `services/wireframe.js`.
 */
const InplaceIconPopover = <template>
  <DIconGridPickerContent @value={{@data.value}} @onSelect={{@data.onSelect}} />
</template>;

export default InplaceIconPopover;
