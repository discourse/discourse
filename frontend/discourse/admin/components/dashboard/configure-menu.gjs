import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import DDragHandle from "discourse/ui-kit/d-drag-handle";
import DReorderButtons from "discourse/ui-kit/d-reorder-buttons";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

class ConfigureRow extends Component {
  /** The grip, so the drag starts there while the whole row is what moves. */
  @tracked gripElement;

  captureGrip = modifier((element) => {
    this.gripElement = element;
    return () => (this.gripElement = undefined);
  });

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
        dragHandle=this.gripElement
      }}
      {{dDragAndDropTarget
        accepts="dashboard-section"
        acceptsSelf=false
        onDrop=this.onRowDrop
      }}
      class="db-configure__row"
      data-section-id={{@section.id}}
    >
      {{! Every viewport, because a touch screen can drag from a grip and had
          no way to reorder at all while this was desktop-only. The drag starts
          here rather than anywhere on the row, so a press that was meant to
          scroll still scrolls. }}
      <DDragHandle
        {{this.captureGrip}}
        @label={{this.dragHandleLabel}}
        class="db-configure__drag-handle"
      />

      {{! The arrows are the keyboard path, which a touch screen does not have
          either, so they render everywhere the grip does. }}
      <DReorderButtons
        @onMoveUp={{fn @onMoveUp @index}}
        @onMoveDown={{fn @onMoveDown @index}}
        @disableUp={{@isFirst}}
        @disableDown={{@isLast}}
        @upLabel={{this.reorderUpLabel}}
        @downLabel={{this.reorderDownLabel}}
        class="db-configure__arrows"
      />

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
  @service a11y;

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

    this.#reorder(fromIndex, toIndex);
  }

  @action
  onMoveUp(index) {
    if (index > 0) {
      this.#reorder(index, index - 1);
    }
  }

  @action
  onMoveDown(index) {
    if (index < this.args.sections.length - 1) {
      this.#reorder(index, index + 1);
    }
  }

  /**
   * Commits a reorder and announces where the row landed.
   *
   * Every path in — both arrows and the drag — funnels through here, past its own
   * no-op guard, so a move is announced exactly once and a non-move never is. The
   * destination is taken from `toIndex` rather than re-read from `sections`: this
   * component is controlled, so the list it renders still holds the old order at
   * this point.
   *
   * @param {number} fromIndex - The row's current index.
   * @param {number} toIndex - The index it is moving to.
   */
  #reorder(fromIndex, toIndex) {
    const section = this.args.sections[fromIndex];

    this.args.onReorder(fromIndex, toIndex);

    this.a11y.announce(
      i18n("reorder_announcement", {
        label: i18n(`admin.dashboard.sections.${section.id}.title`),
        position: toIndex + 1,
        total: this.args.sections.length,
      })
    );
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
