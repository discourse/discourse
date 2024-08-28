import Component from "@ember/component";
import { computed } from "@ember/object";
import { equal } from "@ember/object/computed";
import { classNameBindings, tagName } from "@ember-decorators/component";
import { userPath } from "discourse/lib/url";
import { actionDescription } from "discourse/widgets/post-small-action";
import discourseComputed from "discourse-common/utils/decorators";

@tagName("li")
@classNameBindings(
  ":user-stream-item", // DEPRECATED: 'item' class
  ":item",
  "hidden",
  "item.deleted:deleted",
  "moderatorAction"
)
export default class UserStreamItem extends Component {
  @equal("item.post_type", "site.post_types.moderator_action")
  moderatorAction;

  @actionDescription(
    "item.action_code",
    "item.created_at",
    "item.action_code_who",
    "item.action_code_path"
  )
  actionDescription;

  @computed("item.hidden")
  get hidden() {
    return (
      this.get("item.hidden") && !(this.currentUser && this.currentUser.staff)
    );
  }

  @discourseComputed("item.draft_username", "item.username")
  userUrl(draftUsername, username) {
    return userPath((draftUsername || username).toLowerCase());
  }
}
