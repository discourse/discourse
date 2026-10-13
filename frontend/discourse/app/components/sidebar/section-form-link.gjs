import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import withEventValue from "discourse/helpers/with-event-value";
import discourseLater from "discourse/lib/later";
import DButton from "discourse/ui-kit/d-button";
import DIconGridPicker from "discourse/ui-kit/d-icon-grid-picker";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
import { i18n } from "discourse-i18n";

export default class SectionFormLink extends Component {
  @service site;

  @tracked dragCssClass;
  dragCount = 0;

  isAboveElement(event) {
    event.preventDefault();
    const target = event.currentTarget;
    const domRect = target.getBoundingClientRect();
    return event.offsetY < domRect.height / 2;
  }

  @action
  dragHasStarted(event) {
    event.dataTransfer.effectAllowed = "move";
    this.args.setDraggedLinkCallback(this.args.link);
    this.dragCssClass = "dragging";
  }

  @action
  dragOver(event) {
    event.preventDefault();
    if (this.dragCssClass !== "dragging") {
      if (this.isAboveElement(event)) {
        this.dragCssClass = "drag-above";
      } else {
        this.dragCssClass = "drag-below";
      }
    }
  }

  @action
  dragEnter() {
    this.dragCount++;
  }

  @action
  dragLeave() {
    this.dragCount--;
    if (
      this.dragCount === 0 &&
      (this.dragCssClass === "drag-above" || this.dragCssClass === "drag-below")
    ) {
      discourseLater(() => {
        this.dragCssClass = null;
      }, 10);
    }
  }

  @action
  dropItem(event) {
    event.stopPropagation();
    this.dragCount = 0;
    this.args.reorderCallback(this.args.link, this.isAboveElement(event));
    this.dragCssClass = null;
  }

  @action
  dragEnd() {
    this.dragCount = 0;
    this.dragCssClass = null;
  }

  <template>
    <div class="sidebar-section-form-link-wrapper" role="rowgroup">
      <div
        class={{dConcatClass
          "sidebar-section-form-link"
          "row-wrapper"
          this.dragCssClass
        }}
        data-row-id={{@link.objectId}}
        role="row"
        {{on "dragover" this.dragOver}}
        {{on "dragenter" this.dragEnter}}
        {{on "dragleave" this.dragLeave}}
        {{on "dragend" this.dragEnd}}
        {{on "drop" this.dropItem}}
      >
        {{#if this.site.desktopView}}
          <div
            class="draggable"
            data-link-name={{@link.name}}
            draggable="true"
            {{on "dragstart" this.dragHasStarted}}
          >
            {{dIcon "grip-lines"}}
          </div>
        {{/if}}

        <div class="input-group" role="cell">
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

        <div class="input-group" role="cell">
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
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

        <div class="input-group" role="cell">
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
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
            {{! Not announced assertively: nothing is wrong yet, and the row
                still saves. }}
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
      </div>
    </div>
  </template>
}
