import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import withEventValue from "discourse/helpers/with-event-value";
import DButton from "discourse/ui-kit/d-button";
import DIconGridPicker from "discourse/ui-kit/d-icon-grid-picker";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

/**
 * One link row's cells inside the section form's reorderable lists. The row
 * element, its drag wiring, and the reorder announcements are the list's; what
 * lives here is the link's own fields plus the placement of the pre-wired
 * controls into the row's grid tracks.
 */
// TODO (ui-kit-reorderable-list-cleanup) rename this over
// `section-form-link.gjs` once the change ships.
const SectionFormLink = <template>
  {{! Every viewport, because a touch screen can drag from a grip and had no
      way to reorder at all while this was desktop-only. The drag starts at the
      grip rather than anywhere on the row, so a press that was meant to
      scroll still scrolls, and its menu carries the paths a drag cannot. }}
  <@controls.handle
    class="draggable"
    data-link-name={{@link.name}}
    role="cell"
  />

  <div class="input-group link-icon" role="cell">
    <DIconGridPicker
      aria-label={{i18n "sidebar.sections.custom.links.icon.label"}}
      @btnClass={{dConcatClass "btn-default" @link.iconCssClass}}
      @onChange={{fn (mut @link.icon)}}
      @showCaret={{true}}
      @value={{@link.icon}}
    />

    {{#if @link.invalidIconMessage}}
      <div aria-live="assertive" class="icon warning" role="alert">
        {{@link.invalidIconMessage}}
      </div>
    {{/if}}
  </div>

  <div class="input-group link-name" role="cell">

    <Input
      aria-label={{i18n "sidebar.sections.custom.links.name.label"}}
      class={{@link.nameCssClass}}
      data-1p-ignore
      name="link-name"
      @type="text"
      @value={{@link.name}}
      {{(if @focusNameInput (modifier dAutoFocus selectText=true))}}
      {{on "input" (withEventValue (fn (mut @link.name)))}}
    />

    {{#if @link.invalidNameMessage}}
      <div aria-live="assertive" class="name warning" role="alert">
        {{@link.invalidNameMessage}}
      </div>
    {{/if}}
  </div>

  <div class="input-group link-url" role="cell">

    <Input
      aria-label={{i18n "sidebar.sections.custom.links.value.label"}}
      class={{@link.valueCssClass}}
      name="link-url"
      @type="text"
      @value={{@link.value}}
      {{on "input" (withEventValue (fn (mut @link.value)))}}
    />

    {{#if @link.invalidValueMessage}}
      <div aria-live="assertive" class="value warning" role="alert">
        {{@link.invalidValueMessage}}
      </div>
    {{else if @duplicateValue}}
      {{! Not announced assertively: nothing is wrong yet, and the row still
          saves. }}
      <div class="value warning duplicate-link">
        {{i18n "sidebar.sections.custom.links.value.duplicate"}}
      </div>
    {{/if}}
  </div>

  <DButton
    class="btn-flat delete-link"
    role="cell"
    @action={{fn @deleteLink @link}}
    @icon="trash-can"
    @title="sidebar.sections.custom.links.delete"
  />
</template>;

export default SectionFormLink;
