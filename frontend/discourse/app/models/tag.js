import { readOnly } from "@ember/object/computed";
import discourseComputed from "discourse/lib/decorators";
import RestModel from "discourse/models/rest";

export default class Tag extends RestModel {
  @readOnly("pm_only") pmOnly;

  @discourseComputed("count", "pm_count")
  totalCount(count, pmCount) {
    return pmCount ? count + pmCount : count;
  }

  @discourseComputed("id", "name")
  searchContext(id, name) {
    return {
      type: "tag",
      id,
      /** @type Tag */
      tag: this,
      name,
    };
  }

  // override update to pass name instead of id to the adapter
  // since the backend tag routes use tag name in the URL path
  update(props) {
    if (this.isSaving) {
      return Promise.reject();
    }

    props = props || this.updateProperties();

    this.beforeUpdate(props);

    const tagName = this.name || this.get("name") || this.id;

    this.set("isSaving", true);
    return this.store
      .update(this.__type, tagName, props)
      .then((res) => {
        const payload = this.__munge(res.payload || res.responseJson);

        if (payload.success === "OK") {
          res = props;
        }

        this.setProperties(payload);
        this.afterUpdate(res);
        res.target = this;
        return res;
      })
      .finally(() => this.set("isSaving", false));
  }
}
