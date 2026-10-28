import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

/**
 * Theme mutations shared by the themes list and the theme editor. Each action
 * confirms, requests, and reports its result through a callback so callers can
 * update their own state.
 */
export default class BlogThemeActions extends Service {
  @service dialog;
  @service toasts;

  @tracked busy = false;

  activate(theme, { onActivated } = {}) {
    this.dialog.confirm({
      message: i18n("blog.admin.activate_confirm", {
        name: theme.name,
      }),
      didConfirm: async () => {
        const active = await this.#request(`/${theme.id}/activate`, "POST", {
          revision: theme.revision,
        });

        if (active) {
          this.toasts.success({
            data: { message: i18n("blog.admin.activated") },
          });
          onActivated?.(active);
        }
      },
    });
  }

  pull(theme, { onPulled } = {}) {
    this.dialog.confirm({
      message: i18n("blog.admin.pull_confirm"),
      didConfirm: async () => {
        const updated = await this.#request(`/${theme.id}/pull`, "POST", {
          revision: theme.revision,
        });

        if (updated) {
          onPulled?.(updated);
        }
      },
    });
  }

  remove(theme, { onRemoved } = {}) {
    this.dialog.confirm({
      message: i18n("blog.admin.delete_confirm", {
        name: theme.name,
      }),
      didConfirm: async () => {
        const result = await this.#request(`/${theme.id}`, "DELETE", {
          revision: theme.revision,
        });

        if (result !== false) {
          onRemoved?.();
        }
      },
    });
  }

  async #request(path, type, data) {
    this.busy = true;

    try {
      return await ajax(`/blog/themes${path}.json`, { type, data });
    } catch (error) {
      popupAjaxError(error);
      return false;
    } finally {
      this.busy = false;
    }
  }
}
