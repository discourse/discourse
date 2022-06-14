import { action } from "@ember/object";

import GlimmerComponent from "discourse/components/glimmer";
import Composer from "discourse/models/composer";
import { getOwner } from "discourse-common/lib/get-owner";

export default class SidebarMessagesSection extends GlimmerComponent {
  @action
  composePersonalMessage() {
    const composerArgs = {
      action: Composer.PRIVATE_MESSAGE,
      draftKey: Composer.NEW_TOPIC_KEY,
    };

    getOwner(this).lookup("controller:composer").open(composerArgs);
  }
}
