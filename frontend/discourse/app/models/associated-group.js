import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AssociatedGroup extends EmberObject {
  static list() {
    return ajax("/associated_groups")
      .then((result) => {
        return result.associated_groups.map((ag) => AssociatedGroup.create(ag));
      })
      .catch(popupAjaxError);
  }
}
