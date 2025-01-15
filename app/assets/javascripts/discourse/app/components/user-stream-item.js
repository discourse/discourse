/*
 *  !!! DEPRECATED COMPNENT: DO NOT USE !!!
 *  Instead use `<PostList />` component to render a post list.
 *  TODO(keegan): Remove this component once all plugin/theme component instances have been updated
 */
import Component from "@ember/component";
import { computed } from "@ember/object";
import { classNameBindings, tagName } from "@ember-decorators/component";
import { propertyEqual } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { userPath } from "discourse/lib/url";
import { actionDescription } from "discourse/widgets/post-small-action";

@tagName("li")
@classNameBindings(
  ":user-stream-item",
  ":item", // DEPRECATED: 'item' class
  "hidden",
  "item.deleted:deleted",
  "moderatorAction"
)
export default class UserStreamItem extends Component {
  @propertyEqual("item.post_type", "site.post_types.moderator_action")
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
