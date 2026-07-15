import { tracked } from "@glimmer/tracking";
import EmberObject, { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  removeValueFromArray,
  uniqueItemsFromArray,
} from "discourse/lib/array-tools";
import getURL from "discourse/lib/get-url";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import Session from "discourse/models/session";
import { i18n } from "discourse-i18n";

const ALL_FILTER = "all";
const DEFAULT_GROUP = "default";

export default class AdminEmojis extends Service {
  @service dialog;

  @tracked filter = ALL_FILTER;
  @tracked sorting = ["group", "name"];
  @tracked selectedEmojis = new Set();
  @tracked isSelecting = false;
  @tracked isExporting = false;
  @autoTrackedArray emojis = [];

  constructor() {
    super(...arguments);
    this.#fetchEmojis();
  }

  get filteredEmojis() {
    if (!this.filter || this.filter === ALL_FILTER) {
      return this.emojis;
    } else {
      return this.emojis.filter((e) => e.group === this.filter);
    }
  }

  get sortedEmojis() {
    const selected = this.selectedEmojis;
    return this.filteredEmojis
      .toSorted((a, b) => a.name.localeCompare(b.name))
      .map((e) => {
        e.set("isSelected", selected.has(e.get("name")));
        return e;
      });
  }

  get emojiGroups() {
    return uniqueItemsFromArray(
      [DEFAULT_GROUP].concat(this.emojis.map((e) => e.group))
    );
  }

  get filteringGroups() {
    return [ALL_FILTER].concat(this.emojiGroups);
  }

  get allVisibleSelected() {
    const visible = this.sortedEmojis;
    return (
      visible.length > 0 &&
      visible.every((e) => this.selectedEmojis.has(e.get("name")))
    );
  }

  get someVisibleSelected() {
    return (
      !this.allVisibleSelected &&
      this.sortedEmojis.some((e) => this.selectedEmojis.has(e.get("name")))
    );
  }

  get selectedCount() {
    return this.selectedEmojis.size;
  }

  get exportDisabled() {
    return this.selectedEmojis.size === 0;
  }

  get exportLabel() {
    const count = this.selectedEmojis.size;
    if (count === 0) {
      return i18n("admin.export_json.button_text");
    }
    return i18n("admin.emoji.export_count", { count });
  }

  @action
  async exportSelected() {
    if (this.exportDisabled || this.isExporting) {
      return;
    }

    this.isExporting = true;

    try {
      const response = await fetch(getURL("/admin/config/emoji/export"), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": Session.currentProp("csrfToken"),
        },
        body: JSON.stringify({ names: [...this.selectedEmojis] }),
      });

      if (!response.ok) {
        const data = await response.json().catch(() => ({}));
        this.dialog.alert(
          data.errors?.[0] || i18n("admin.emoji.export_failed")
        );
        return;
      }

      const blob = await response.blob();
      const objectUrl = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = objectUrl;
      a.download = "emojis.zip";
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      setTimeout(() => URL.revokeObjectURL(objectUrl), 20_000);
    } catch {
      this.dialog.alert(i18n("admin.emoji.export_failed"));
    } finally {
      this.isExporting = false;
    }
  }

  @action
  startSelecting() {
    this.isSelecting = true;
    this.selectedEmojis = new Set();
  }

  @action
  cancelSelecting() {
    this.isSelecting = false;
    this.selectedEmojis = new Set();
  }

  @action
  toggleEmojiSelected(emoji) {
    const name = emoji.get("name");
    const next = new Set(this.selectedEmojis);
    if (next.has(name)) {
      next.delete(name);
    } else {
      next.add(name);
    }
    this.selectedEmojis = next;
  }

  @action
  toggleAllVisible() {
    const next = new Set(this.selectedEmojis);
    if (this.allVisibleSelected) {
      this.sortedEmojis.forEach((e) => next.delete(e.get("name")));
    } else {
      this.sortedEmojis.forEach((e) => next.add(e.get("name")));
    }
    this.selectedEmojis = next;
  }

  @action
  destroyEmoji(emoji) {
    this.dialog.deleteConfirm({
      title: i18n("admin.emoji.delete_confirm", {
        name: emoji.get("name"),
      }),
      didConfirm: () => this.#destroyEmoji(emoji),
    });
  }

  async #fetchEmojis() {
    try {
      const data = await ajax("/admin/config/emoji.json");
      this.emojis = data.map((emoji) => EmberObject.create(emoji));
    } catch (err) {
      popupAjaxError(err);
    }
  }

  async #destroyEmoji(emoji) {
    try {
      await ajax("/admin/config/emoji/" + emoji.get("name"), {
        type: "DELETE",
      });
      removeValueFromArray(this.emojis, emoji);
      const next = new Set(this.selectedEmojis);
      next.delete(emoji.get("name"));
      this.selectedEmojis = next;
    } catch (err) {
      popupAjaxError(err);
    }
  }
}
