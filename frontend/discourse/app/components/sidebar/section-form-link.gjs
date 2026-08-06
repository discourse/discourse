import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import withEventValue from "discourse/helpers/with-event-value";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DIconGridPicker from "discourse/ui-kit/d-icon-grid-picker";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

export default class SectionFormLink extends Component {
  @service site;

  /**
   * The grip element, once it exists. Held as tracked state rather than looked up,
   * and the drag source re-registers when it arrives: the grip renders on desktop
   * only, so its ref reaches the modifier's args on a later run.
   */
  @tracked gripElement;

  captureGrip = modifier((element) => {
    this.gripElement = element;
    return () => (this.gripElement = undefined);
  });

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
          disabled=(not this.site.desktopView)
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
        {{#if this.site.desktopView}}
          <div
            {{this.captureGrip}}
            class="draggable"
            data-link-name={{@link.name}}
          >
            {{dIcon "grip-lines"}}
          </div>
        {{/if}}

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
