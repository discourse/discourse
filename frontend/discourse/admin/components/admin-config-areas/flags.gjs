import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminFlagItem from "discourse/admin/components/admin-flag-item";
import { SYSTEM_FLAG_IDS } from "discourse/admin/lib/constants";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class AdminConfigAreasFlags extends Component {
  @service site;

  /**
   * Flags with a request in flight, so their rows can drop the `saved`
   * marker while a toggle, delete, or reorder is being persisted. Held here
   * because the list owns the row elements the marker paints.
   */
  @tracked pendingIds = new Set();
  @autoTrackedArray flags = this.site.flagTypes;

  flagLabel = (flag) => flag.name;

  movable = (flag) => flag.id !== SYSTEM_FLAG_IDS.notify_user;

  rowClass = (flag) =>
    dConcatClass(
      "d-table__row admin-flag-item",
      flag.name_key,
      this.pendingIds.has(flag.id) ? null : "saved"
    );

  @action
  setPending(flag, pending) {
    const next = new Set(this.pendingIds);
    if (pending) {
      next.add(flag.id);
    } else {
      next.delete(flag.id);
    }
    this.pendingIds = next;
  }

  /**
   * Applies a committed move optimistically and persists it through the
   * single-step reorder endpoint, rolling back on failure. Arrow moves are
   * always adjacent steps, which is why the surface stays arrows-only for
   * now: a pointer drag could jump several rows at once, which this endpoint
   * cannot express.
   *
   * @param {Object} move - The normalized move from the list.
   */
  @action
  async handleMove(move) {
    const fallbackFlags = [...this.flags];
    this.setPending(move.item, true);
    this.flags.splice(0, this.flags.length, ...move.proposedToItems);

    const direction = move.toIndex > move.fromIndex ? "down" : "up";
    try {
      await ajax(`/admin/config/flags/${move.item.id}/reorder/${direction}`, {
        type: "PUT",
      });
    } catch (error) {
      this.flags.splice(0, this.flags.length, ...fallbackFlags);
      return popupAjaxError(error);
    } finally {
      this.setPending(move.item, false);
    }
  }

  @action
  async deleteFlagCallback(flag) {
    try {
      await ajax(`/admin/config/flags/${flag.id}`, {
        type: "DELETE",
      });

      removeValueFromArray(this.flags, flag);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="container admin-flags">
      {{! The reorderable list renders the tbody itself, which the static
          table-group rule cannot see from here. }}
      {{! eslint-disable-next-line ember/template-table-groups }}
      <table class="d-table admin-flags__items">
        <thead class="d-table__header">
          <th class="d-table__header-cell">{{i18n
              "admin.config_areas.flags.description"
            }}</th>
          <th class="d-table__header-cell">{{i18n
              "admin.config_areas.flags.enabled"
            }}</th>
        </thead>
        <DReorderableList
          @items={{this.flags}}
          @key="id"
          @label={{this.flagLabel}}
          @movable={{this.movable}}
          @onMove={{this.handleMove}}
          @controls="manual"
          @tag="tbody"
          @itemTag="tr"
          @rowClass={{this.rowClass}}
          class="d-table__body"
        >
          <:default as |flag row|>
            <AdminFlagItem
              @row={{row}}
              @flag={{flag}}
              @deleteFlagCallback={{this.deleteFlagCallback}}
              @setPending={{this.setPending}}
            />
          </:default>
        </DReorderableList>
      </table>
    </div>
  </template>
}
