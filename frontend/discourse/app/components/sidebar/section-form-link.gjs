import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier as createModifier } from "ember-modifier";
import withEventValue from "discourse/helpers/with-event-value";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DDragHandle from "discourse/ui-kit/d-drag-handle";
import DIconGridPicker from "discourse/ui-kit/d-icon-grid-picker";
import DReorderButtons from "discourse/ui-kit/d-reorder-buttons";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class SectionFormLink extends Component {
  /**
   * The grip element, once it exists. Held as tracked state rather than looked up,
   * and the drag source re-registers when it arrives: the grip renders on desktop
   * only, so its ref reaches the modifier's args on a later run.
   */
  @tracked gripElement;

  captureGrip = createModifier((element) => {
    this.gripElement = element;
    return () => (this.gripElement = undefined);
  });

  get dragHandleLabel() {
    return i18n("sidebar.sections.custom.links.drag_handle", {
      label: this.args.link.name,
    });
  }

  get moveDownLabel() {
    return i18n("sidebar.sections.custom.links.move_down", {
      label: this.args.link.name,
    });
  }

  get moveUpLabel() {
    return i18n("sidebar.sections.custom.links.move_up", {
      label: this.args.link.name,
    });
  }

  /**
   * Resolves a drop onto this row into a reorder.
   *
   * The dragged link travels as the payload, never its `segment` or `isPrimary`:
   * those are read once when the drag starts, and the reorder mutates `segment` as
   * it moves the link, so a snapshot would be of exactly the value being
   * invalidated. The destination comes from this row's own link instead.
   *
   * @param {Object} params - The drop payload.
   * @param {Object} params.source - The dragged source, carrying `data.link`.
   * @param {string} params.position - Whether the drop landed before or after.
   */
  @action
  onRowDrop({ source, position }) {
    this.args.reorderCallback(source.data.link, this.args.link, position);
  }

  <template>
    <div class="sidebar-section-form-link-wrapper" role="rowgroup">
      <div
        {{dDragAndDropSource
          type="sidebar-link"
          data=(hash link=@link)
          dragHandle=this.gripElement
        }}
        {{dDragAndDropTarget
          accepts="sidebar-link"
          acceptsSelf=false
          onDrop=this.onRowDrop
        }}
        role="row"
        data-row-id={{@link.objectId}}
        class={{dConcatClass "sidebar-section-form-link" "row-wrapper"}}
      >
        {{! Every viewport, because a touch screen can drag from a grip and had
            no way to reorder at all while this was desktop-only. The drag
            starts here rather than anywhere on the row, so a press that was
            meant to scroll still scrolls. }}
        <DDragHandle
          {{this.captureGrip}}
          @label={{this.dragHandleLabel}}
          class="draggable"
          data-link-name={{@link.name}}
        />

        {{! The arrows are the keyboard path, which a touch screen does not
            have either, so they render everywhere the grip does. }}
        <DReorderButtons
          @onMoveUp={{fn @moveUp @link}}
          @onMoveDown={{fn @moveDown @link}}
          @disableUp={{eq @index 0}}
          @disableDown={{eq @index @lastIndex}}
          @upLabel={{this.moveUpLabel}}
          @downLabel={{this.moveDownLabel}}
          role="cell"
          class="sidebar-section-form-link__arrows"
        />

        <div class="input-group" role="cell">
          <DIconGridPicker
            @value={{@link.icon}}
            @onChange={{fn (mut @link.icon)}}
            @showCaret={{true}}
            @btnClass={{dConcatClass "btn-default" @link.iconCssClass}}
            aria-label={{i18n "sidebar.sections.custom.links.icon.label"}}
          />

          {{#if @link.invalidIconMessage}}
            <div class="icon warning" role="alert" aria-live="assertive">
              {{@link.invalidIconMessage}}
            </div>
          {{/if}}
        </div>

        <div class="input-group" role="cell">
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <Input
            {{(if @focusNameInput (modifier dAutoFocus selectText=true))}}
            {{on "input" (withEventValue (fn (mut @link.name)))}}
            @type="text"
            @value={{@link.name}}
            name="link-name"
            aria-label={{i18n "sidebar.sections.custom.links.name.label"}}
            class={{@link.nameCssClass}}
            data-1p-ignore
          />

          {{#if @link.invalidNameMessage}}
            <div role="alert" aria-live="assertive" class="name warning">
              {{@link.invalidNameMessage}}
            </div>
          {{/if}}
        </div>

        <div class="input-group" role="cell">
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <Input
            {{on "input" (withEventValue (fn (mut @link.value)))}}
            @type="text"
            @value={{@link.value}}
            name="link-url"
            aria-label={{i18n "sidebar.sections.custom.links.value.label"}}
            class={{@link.valueCssClass}}
          />

          {{#if @link.invalidValueMessage}}
            <div role="alert" aria-live="assertive" class="value warning">
              {{@link.invalidValueMessage}}
            </div>
          {{else if @duplicateValue}}
            {{! Not announced assertively: nothing is wrong yet, and the row
                still saves. }}
            <div class="value warning duplicate-link">
              {{i18n "sidebar.sections.custom.links.value.duplicate"}}
            </div>
          {{/if}}
        </div>

        <DButton
          @icon="trash-can"
          @action={{fn @deleteLink @link}}
          @title="sidebar.sections.custom.links.delete"
          role="cell"
          class="btn-flat delete-link"
        />
      </div>
    </div>
  </template>
}
