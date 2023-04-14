import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const AssociatedGroup = EmberObject.extend();

AssociatedGroup.reopenClass({
  list() {
    return ajax("/associated_groups")
      .then((result) => {
        return result.associated_groups.map((ag) => AssociatedGroup.create(ag));
      })
      .catch(popupAjaxError);
  },
});

export default AssociatedGroup;
