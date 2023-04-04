import Component from "@ember/component";
import { actionDescription } from "discourse/widgets/post-small-action";
import { computed } from "@ember/object";
import { propertyEqual } from "discourse/lib/computed";
import { userPath } from "discourse/lib/url";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  tagName: "li",

  classNameBindings: [
    ":user-stream-item",
    ":item", // DEPRECATED: 'item' class
    "hidden",
    "item.deleted:deleted",
    "moderatorAction",
  ],

  hidden: computed("item.hidden", function () {
    return (
      this.get("item.hidden") && !(this.currentUser && this.currentUser.staff)
    );
  }),
  moderatorAction: propertyEqual(
    "item.post_type",
    "site.post_types.moderator_action"
  ),
  actionDescription: actionDescription(
    "item.action_code",
    "item.created_at",
    "item.action_code_who",
    "item.action_code_path",
    "item.extra_small_action_translation_args",
  ),

  @discourseComputed("item.draft_username", "item.username")
  userUrl(draftUsername, username) {
    return userPath((draftUsername || username).toLowerCase());
  },
});
