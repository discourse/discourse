import Component from "@ember/component";
import { propertyEqual } from "discourse/lib/computed";
import { actionDescription } from "discourse/widgets/post-small-action";

export default Component.extend({
  classNameBindings: [
    ":user-stream-item",
    ":item", // DEPRECATED: 'item' class
    "item.hidden",
    "item.deleted:deleted",
    "moderatorAction"
  ],

  moderatorAction: propertyEqual(
    "item.post_type",
    "site.post_types.moderator_action"
  ),
  actionDescription: actionDescription(
    "item.action_code",
    "item.created_at",
    "item.action_code_who"
  )
});
