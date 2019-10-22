import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default DiscourseRoute.extend({
  model: function() {
    return ajax("/admin/customize/emojis.json").then(function(emojis) {
      return emojis.map(function(emoji) {
        return Ember.Object.create(emoji);
      });
    });
  }
});
