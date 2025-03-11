import Component from "@ember/component";
import { computed } from "@ember/object";
import { classNameBindings, tagName } from "@ember-decorators/component";
import { propertyEqual } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
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

  constructor() {
    super(...arguments);
    deprecated(
      `<UserStreamItem /> component is deprecated. Use <PostList /> or <UserStream /> component to render a post list instead.`,
      {
        since: "3.4.0.beta4",
        dropFrom: "3.5.0.beta1",
        id: "discourse.user-stream-item",
      }
    );
  }

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
