import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import discourseLater from "discourse/lib/later";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

class ConfigureRow extends Component {
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
  dragStart(event) {
    event.dataTransfer.effectAllowed = "move";
    this.args.onDragStart(this.args.index);
    this.dragCssClass = "dragging";
  }

  @action
  dragOver(event) {
    event.preventDefault();
    if (this.dragCssClass === "dragging") {
      return;
    }
    this.dragCssClass = this.isAboveElement(event)
      ? "drag-above"
      : "drag-below";
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
      discourseLater(() => (this.dragCssClass = null), 10);
    }
  }

  @action
  drop(event) {
    event.stopPropagation();
    this.dragCount = 0;
    const dropAbove = this.isAboveElement(event);
    this.dragCssClass = null;
    this.args.onDrop(this.args.index, dropAbove);
  }

  @action
  dragEnd() {
    this.dragCount = 0;
    this.dragCssClass = null;
  }

  get sectionLabel() {
    return i18n(`admin.dashboard.sections.${this.args.section.id}.title`);
  }

  get reorderUpLabel() {
    return i18n("admin.dashboard.configure.reorder_up", {
      label: this.sectionLabel,
    });
  }

  get reorderDownLabel() {
    return i18n("admin.dashboard.configure.reorder_down", {
      label: this.sectionLabel,
    });
  }

  get dragHandleLabel() {
    return i18n("admin.dashboard.configure.drag_handle", {
      label: this.sectionLabel,
    });
  }

  get toggleLabel() {
    return i18n("admin.dashboard.configure.toggle_visibility", {
      label: this.sectionLabel,
    });
  }

  <template>
    <li
      {{on "dragstart" this.dragStart}}
      {{on "dragover" this.dragOver}}
      {{on "dragenter" this.dragEnter}}
      {{on "dragleave" this.dragLeave}}
      {{on "drop" this.drop}}
      {{on "dragend" this.dragEnd}}
      class={{dConcatClass "db-configure__row" this.dragCssClass}}
      data-section-id={{@section.id}}
      draggable="true"
    >
      {{#if this.site.desktopView}}
        <span
          class="db-configure__drag-handle"
          aria-hidden="true"
          tabindex="-1"
          title={{this.dragHandleLabel}}
        >{{dIcon "grip-vertical"}}</span>
      {{else}}
        <span class="db-configure__arrows">
          <DButton
            @icon="chevron-up"
            @action={{fn @onMoveUp @index}}
            @disabled={{@isFirst}}
            @translatedAriaLabel={{this.reorderUpLabel}}
            @translatedTitle={{this.reorderUpLabel}}
            class="btn-flat db-configure__arrow"
          />
          <DButton
            @icon="chevron-down"
            @action={{fn @onMoveDown @index}}
            @disabled={{@isLast}}
            @translatedAriaLabel={{this.reorderDownLabel}}
            @translatedTitle={{this.reorderDownLabel}}
            class="btn-flat db-configure__arrow"
          />
        </span>
      {{/if}}

      <span class="db-configure__section-name">{{this.sectionLabel}}</span>

      <DToggleSwitch
        @state={{@section.visible}}
        {{on "click" (fn @onToggle @section.id)}}
        aria-label={{this.toggleLabel}}
      />
    </li>
  </template>
}

export default class ConfigureMenu extends Component {
  draggedIndex = null;

  get lastIndex() {
    return (this.args.sections?.length ?? 0) - 1;
  }

  @action
  onDragStart(index) {
    this.draggedIndex = index;
  }

  @action
  onDrop(targetIndex, dropAbove) {
    const fromIndex = this.draggedIndex;
    this.draggedIndex = null;
    if (fromIndex == null || fromIndex === targetIndex) {
      return;
    }

    let toIndex = dropAbove ? targetIndex : targetIndex + 1;
    if (fromIndex < toIndex) {
      toIndex -= 1;
    }
    if (fromIndex === toIndex) {
      return;
    }

    this.args.onReorder(fromIndex, toIndex);
  }

  @action
  onMoveUp(index) {
    if (index > 0) {
      this.args.onReorder(index, index - 1);
    }
  }

  @action
  onMoveDown(index) {
    if (index < this.args.sections.length - 1) {
      this.args.onReorder(index, index + 1);
    }
  }

  <template>
    <div class="db-configure">
      <ul
        class="db-configure__list"
        aria-label={{i18n "admin.dashboard.configure.menu_title"}}
      >
        {{#each @sections key="id" as |section index|}}
          <ConfigureRow
            @section={{section}}
            @index={{index}}
            @isFirst={{eq index 0}}
            @isLast={{eq index this.lastIndex}}
            @onDragStart={{this.onDragStart}}
            @onDrop={{this.onDrop}}
            @onMoveUp={{this.onMoveUp}}
            @onMoveDown={{this.onMoveDown}}
            @onToggle={{@onToggleVisibility}}
          />
        {{/each}}
      </ul>
    </div>
  </template>
}
