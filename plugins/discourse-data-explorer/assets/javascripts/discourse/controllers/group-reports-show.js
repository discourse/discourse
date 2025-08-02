import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BookmarkModal from "discourse/components/modal/bookmark";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { BookmarkFormData } from "discourse/lib/bookmark-form-data";
import { bind } from "discourse/lib/decorators";
import {
  NO_REMINDER_ICON,
  WITH_REMINDER_ICON,
} from "discourse/models/bookmark";
import { ParamValidationError } from "discourse/plugins/discourse-data-explorer/discourse/components/param-input-form";

export default class GroupReportsShowController extends Controller {
  @service currentUser;
  @service modal;
  @service router;

  @tracked showResults = false;
  @tracked loading = false;
  @tracked results = this.model.results;
  @tracked queryGroupBookmark = this.queryGroup?.bookmark;

  queryParams = ["params"];
  form = null;
  explain = false;

  get parsedParams() {
    return this.params ? JSON.parse(this.params) : null;
  }

  get hasParams() {
    return this.model.param_info.length > 0;
  }

  get bookmarkLabel() {
    return this.queryGroupBookmark
      ? "bookmarked.edit_bookmark"
      : "bookmarked.title";
  }

  get bookmarkIcon() {
    if (this.queryGroupBookmark && this.queryGroupBookmark.reminder_at) {
      return WITH_REMINDER_ICON;
    }
    return NO_REMINDER_ICON;
  }

  get bookmarkClassName() {
    return this.queryGroupBookmark
      ? ["query-group-bookmark", "bookmarked"].join(" ")
      : "query-group-bookmark";
  }

  @bind
  async run() {
    try {
      let params = null;
      if (this.hasParams) {
        params = await this.form.submit();
        if (params == null) {
          return;
        }
      }
      this.loading = true;
      this.showResults = false;
      const stringifiedParams = JSON.stringify(params);
      this.router.transitionTo({
        queryParams: {
          params: params ? stringifiedParams : null,
        },
      });
      const response = await ajax(
        `/g/${this.get("group.name")}/reports/${this.model.id}/run`,
        {
          type: "POST",
          data: {
            params: stringifiedParams,
            explain: this.explain,
          },
        }
      );

      this.results = response;
      if (!response.success) {
        return;
      }
      this.showResults = true;
    } catch (error) {
      if (error.jqXHR?.status === 422 && error.jqXHR.responseJSON) {
        this.results = error.jqXHR.responseJSON;
      } else if (!(error instanceof ParamValidationError)) {
        popupAjaxError(error);
      }
    } finally {
      this.loading = false;
    }
  }

  @action
  toggleBookmark() {
    const modalBookmark =
      this.queryGroupBookmark ||
      this.store.createRecord("bookmark", {
        bookmarkable_type: "DiscourseDataExplorer::QueryGroup",
        bookmarkable_id: this.queryGroup.id,
        user_id: this.currentUser.id,
      });
    return this.modal.show(BookmarkModal, {
      model: {
        bookmark: new BookmarkFormData(modalBookmark),
        afterSave: (bookmarkFormData) => {
          const bookmark = this.store.createRecord(
            "bookmark",
            bookmarkFormData.saveData
          );
          this.queryGroupBookmark = bookmark;
          this.appEvents.trigger(
            "bookmarks:changed",
            bookmarkFormData.saveData,
            bookmark.attachedTo()
          );
        },
        afterDelete: () => {
          this.queryGroupBookmark = null;
        },
      },
    });
  }

  @action
  onRegisterApi(form) {
    this.form = form;
  }
}
