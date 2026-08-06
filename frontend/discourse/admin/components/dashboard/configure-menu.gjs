import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

class ConfigureRow extends Component {
  @service site;

  /**
   * Resolves a drop onto this row into a reorder.
   *
   * Both indices arrive with the drop — the dragged one as the payload, this row's
   * from its own args — so nothing has to be remembered from when the drag started.
   *
   * @param {Object} params - The drop payload.
   * @param {Object} params.source - The dragged source, carrying `data.index`.
   * @param {string} params.position - Whether the drop landed before or after.
   */
  @action
  onRowDrop({ source, position }) {
    this.args.onDrop(source.data.index, this.args.index, position === "before");
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
      {{dDragAndDropSource
        type="dashboard-section"
        data=(hash index=@index)
        disabled=(not this.site.desktopView)
      }}
      {{dDragAndDropTarget
        accepts="dashboard-section"
        acceptsSelf=false
        onDrop=this.onRowDrop
      }}
      class="db-configure__row"
      data-section-id={{@section.id}}
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
  get lastIndex() {
    return (this.args.sections?.length ?? 0) - 1;
  }

  @action
  onDrop(fromIndex, targetIndex, dropAbove) {
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
