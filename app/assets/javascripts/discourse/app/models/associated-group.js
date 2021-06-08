import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

const AssociatedGroup = EmberObject.extend({
  @discourseComputed
  label: function () {
    let providerLabel = this.provider_name;
    if (this.provider_domain) {
      providerLabel += `:${this.provider_domain}`;
    }
    return `${providerLabel}:${this.name}`;
  },
});

AssociatedGroup.reopenClass({
  list: function () {
    return ajax("/associated_groups").then(function (result) {
      return result.associated_groups.map((associated_group) => {
        return AssociatedGroup.create(associated_group);
      });
    });
  },
});

export default AssociatedGroup;
