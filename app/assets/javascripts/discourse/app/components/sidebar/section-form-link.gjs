import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import withEventValue from "discourse/helpers/with-event-value";
import discourseLater from "discourse-common/lib/later";
import { i18n } from "discourse-i18n";
import IconPicker from "select-kit/components/icon-picker";

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
    <div
      {{on "dragstart" this.dragHasStarted}}
      {{on "dragover" this.dragOver}}
      {{on "dragenter" this.dragEnter}}
      {{on "dragleave" this.dragLeave}}
      {{on "dragend" this.dragEnd}}
      {{on "drop" this.dropItem}}
      role="row"
      data-row-id={{@link.objectId}}
      draggable="true"
      class={{concatClass
        "sidebar-section-form-link"
        "row-wrapper"
        this.dragCssClass
      }}
    >
      {{#if this.site.desktopView}}
        <div class="draggable" data-link-name={{@link.name}}>
          {{icon "grip-lines"}}
        </div>
      {{/if}}

      <div class="input-group" role="cell">
        <IconPicker
          @name="icon"
          @value={{@link.icon}}
          @options={{hash
            maximum=1
            caretDownIcon="caret-down"
            caretUpIcon="caret-up"
            icons=@link.icon
          }}
          @onlyAvailable={{true}}
          @onChange={{fn (mut @link.icon)}}
          aria-label={{i18n "sidebar.sections.custom.links.icon.label"}}
          class={{@link.iconCssClass}}
        />

        {{#if @link.invalidIconMessage}}
          <div class="icon warning" role="alert" aria-live="assertive">
            {{@link.invalidIconMessage}}
          </div>
        {{/if}}
      </div>

      <div class="input-group" role="cell">
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
  </template>
}
