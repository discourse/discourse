/* eslint-disable ember/no-observers */
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { GROUP_VISIBILITY_LEVELS } from "discourse/lib/constants";
import discourseComputed, { debounce } from "discourse/lib/decorators";
import { trackedArray } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";

export default class GroupIndexController extends Controller {
  @service currentUser;
  @service dialog;

  @trackedArray bulkSelection = null;

  queryParams = ["order", "asc", "filter"];
  order = null;
  asc = true;
  filter = null;
  filterInput = null;
  loading = false;
  isBulk = false;
  showActions = false;

  get hasMembers() {
    return this.model.members?.length > 0;
  }

  get canLoadMore() {
    return this.get("model.members")?.length < this.get("model.user_count");
  }

  @observes("filterInput")
  filterInputChanged() {
    this._setFilter();
  }

  @debounce(500)
  _setFilter() {
    this.set("filter", this.filterInput);
  }

  @observes("order", "asc", "filter")
  _filtersChanged() {
    this.reloadMembers(true);
  }

  reloadMembers(refresh) {
    if (this.loading || !this.model) {
      return;
    }

    if (!refresh && !this.canLoadMore) {
      return;
    }

    this.set("loading", true);
    this.model.reloadMembers(this.memberParams, refresh).finally(() => {
      this.set("loading", false);

      if (this.refresh) {
        this.set("bulkSelection", []);
      }
    });
  }

  @discourseComputed("order", "asc", "filter")
  memberParams(order, asc, filter) {
    return { order, asc, filter };
  }

  @discourseComputed("model")
  canManageGroup(model) {
    return this.currentUser?.canManageGroup(model) && !this.model.automatic;
  }

  @discourseComputed
  filterPlaceholder() {
    if (this.currentUser && this.currentUser.admin) {
      return "groups.members.filter_placeholder_admin";
    } else {
      return "groups.members.filter_placeholder";
    }
  }

  @discourseComputed("filter", "members", "model.can_see_members")
  emptyMessageKey(filter, members, canSeeMembers) {
    if (!canSeeMembers) {
      return "groups.members.forbidden";
    } else if (filter) {
      return "groups.members.no_filter_matches";
    } else {
      return "groups.empty.members";
    }
  }

  @action
  loadMore() {
    this.reloadMembers();
  }

  @action
  toggleActions() {
    this.toggleProperty("showActions");
  }

  @action
  actOnGroup(member, actionId) {
    switch (actionId) {
      case "removeMember":
        this.removeMember(member);
        break;
      case "makeOwner":
        this.makeOwner(member.username);
        break;
      case "removeOwner":
        this.removeOwner(member);
        break;
      case "makePrimary":
        member
          .setPrimaryGroup(this.model.id)
          .then(() => member.set("primary", true));
        break;
      case "removePrimary":
        member.setPrimaryGroup(null).then(() => member.set("primary", false));
        break;
    }
  }

  @action
  actOnSelection(selection, actionId) {
    if (!selection || selection.length === 0) {
      return;
    }

    switch (actionId) {
      case "removeMembers":
        return ajax(`/groups/${this.model.id}/members.json`, {
          type: "DELETE",
          data: { user_ids: selection.map((u) => u.id).join(",") },
        }).then(() => {
          this.model.reloadMembers(this.memberParams, true);
          this.set("isBulk", false);
        });

      case "makeOwners":
        return ajax(`/groups/${this.model.id}/owners.json`, {
          type: "PUT",
          data: {
            usernames: selection.map((u) => u.username).join(","),
          },
        }).then(() => {
          selection.forEach((s) => s.set("owner", true));
          this.set("isBulk", false);
        });

      case "removeOwners":
        return ajax(`/admin/groups/${this.model.id}/owners.json`, {
          type: "DELETE",
          data: {
            group: { usernames: selection.map((u) => u.username).join(",") },
          },
        }).then(() => {
          selection.forEach((s) => s.set("owner", false));
          this.set("isBulk", false);
        });

      case "setPrimary":
      case "unsetPrimary":
        const primary = actionId === "setPrimary";
        return ajax(`/admin/groups/${this.model.id}/primary.json`, {
          type: "PUT",
          data: {
            group: { usernames: selection.map((u) => u.username).join(",") },
            primary,
          },
        }).then(() => {
          selection.forEach((s) => s.set("primary", primary));
          this.set("isBulk", false);
        });
    }
  }

  _wouldLoseAccessOnRemoval(user) {
    if (this.currentUser.admin) {
      return false;
    }

    if (user.id !== this.currentUser.id) {
      return false;
    }

    const group = this.model;

    return (
      group.visibility_level === GROUP_VISIBILITY_LEVELS.owners ||
      group.members_visibility_level === GROUP_VISIBILITY_LEVELS.owners
    );
  }

  @action
  async removeMember(user) {
    if (this._wouldLoseAccessOnRemoval(user)) {
      const confirmed = await this.dialog.yesNoConfirm({
        message: i18n("groups.members.remove_member_self_lockout"),
      });

      if (!confirmed) {
        return;
      }
    }

    this.model.removeMember(user, this.memberParams);
  }

  @action
  makeOwner(username) {
    this.model.addOwners(username);
  }

  @action
  async removeOwner(user) {
    if (this._wouldLoseAccessOnRemoval(user)) {
      const confirmed = await this.dialog.yesNoConfirm({
        message: i18n("groups.members.remove_owner_self_lockout"),
      });

      if (!confirmed) {
        return;
      }
    }

    this.model.removeOwner(user);
  }

  @action
  addMembers() {
    if (this.usernames && this.usernames.length > 0) {
      this.model
        .addMembers(this.usernames)
        .then(() => this.set("usernames", []))
        .catch(popupAjaxError);
    }
  }

  @action
  toggleBulkSelect() {
    this.setProperties({
      isBulk: !this.isBulk,
      bulkSelection: [],
    });
  }

  @action
  bulkSelectAll() {
    document
      .querySelectorAll("input.bulk-select:not(:checked)")
      .forEach((checkbox) => {
        if (!checkbox.checked) {
          checkbox.click();
        }
      });
  }

  @action
  bulkClearAll() {
    document
      .querySelectorAll("input.bulk-select:checked")
      .forEach((checkbox) => {
        if (checkbox.checked) {
          checkbox.click();
        }
      });
  }

  @action
  selectMember(member, e) {
    this.set("bulkSelection", this.bulkSelection || []);

    if (e.target.checked) {
      this.bulkSelection.push(member);
    } else {
      removeValueFromArray(this.bulkSelection, member);
    }
  }

  @action
  updateOrder(field, asc) {
    this.setProperties({
      order: field,
      asc,
    });
  }
}
