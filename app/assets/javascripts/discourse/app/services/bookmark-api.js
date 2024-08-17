import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Bookmark from "discourse/models/bookmark";

export default class BookmarkApi extends Service {
  @service currentUser;

  buildNewBookmark(bookmarkableType, bookmarkableId) {
    return Bookmark.createFor(
      this.currentUser,
      bookmarkableType,
      bookmarkableId
    );
  }

  create(bookmarkFormData) {
    return ajax("/bookmarks.json", {
      method: "POST",
      data: bookmarkFormData.saveData,
    })
      .then((response) => {
        bookmarkFormData.id = response.id;
        return bookmarkFormData;
      })
      .catch(popupAjaxError);
  }

  delete(bookmarkId) {
    return ajax(`/bookmarks/${bookmarkId}.json`, {
      method: "DELETE",
    }).catch(popupAjaxError);
  }

  update(bookmarkFormData) {
    return ajax(`/bookmarks/${bookmarkFormData.id}.json`, {
      method: "PUT",
      data: bookmarkFormData.saveData,
    }).catch(popupAjaxError);
  }
}
