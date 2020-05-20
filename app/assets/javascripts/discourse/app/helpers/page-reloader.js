import EmberObject from "@ember/object";
import Ember from "ember";

export default EmberObject.create({
  reload: function() {
    if (!Ember.testing) {
      location.reload();
    }
  }
});
