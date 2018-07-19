import RestModel from "discourse/models/rest";
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import { postUrl } from "discourse/lib/utilities";
import { userPath } from "discourse/lib/url";
import UserAction from "discourse/models/user-action";

const UserDraft = RestModel.extend({
  @on("init")
  _attachCategory() {
    const categoryId = this.get("category_id");
    if (categoryId) {
      this.set("category", Discourse.Category.findById(categoryId));
    }
  },

  @computed("username")
  usernameLower(username) {
    return username.toLowerCase();
  },

  @computed("usernameLower")
  userUrl(usernameLower) {
    return userPath(usernameLower);
  },

  @computed()
  postUrl() {
    return postUrl(
      this.get("slug"),
      this.get("topic_id"),
      this.get("post_number")
    );
  },

  actingDisplayName: Ember.computed.or("name", "username"),
  removableDraft: Em.computed.equal("action_type", UserAction.TYPES.drafts),

  switchToActing() {
    this.setProperties({
      username: this.get("username"),
      name: this.get("actingDisplayName")
    });
  }

});

export default UserDraft;
