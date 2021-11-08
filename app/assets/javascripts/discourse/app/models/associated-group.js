import EmberObject from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const AssociatedGroup = EmberObject.extend({
  @discourseComputed
  label() {
    return `${this.provider_name}:${this.name}`;
  },
});

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
