import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import computed from "ember-addons/ember-computed-decorators";
import Category from "discourse/models/category";

const PENDING = 0;
const APPROVED = 1;
const REJECTED = 2;
const IGNORED = 3;

export default RestModel.extend({
  pending: Ember.computed.equal("status", PENDING),
  approved: Ember.computed.equal("status", APPROVED),
  rejected: Ember.computed.equal("status", REJECTED),
  ignored: Ember.computed.equal("status", IGNORED),

  @computed("type")
  humanType(type) {
    return I18n.t(`review.types.${type.underscore()}.title`, {
      defaultValue: ""
    });
  },

  update(updates) {
    // If no changes, do nothing
    if (Object.keys(updates).length === 0) {
      return Ember.RSVP.resolve();
    }

    let adapter = this.store.adapterFor("reviewable");
    return ajax(
      `/review/${this.get("id")}?version=${this.get("version")}`,
      adapter.getPayload("PUT", { reviewable: updates })
    ).then(updated => {
      updated.payload = Object.assign(
        {},
        this.get("payload") || {},
        updated.payload || {}
      );

      if (updated.category_id) {
        updated.category = Category.findById(updated.category_id);
        delete updated.category_id;
      }

      this.setProperties(updated);
    });
  }
});
