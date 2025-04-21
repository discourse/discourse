import Component from "@glimmer/component";
import { gte } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class MembersCount extends Component {
  get countLabel() {
    return i18n("chat.direct_message_creator.members_counter", {
      count: this.args.count,
      max: this.args.max,
    });
  }

  <template>
    <div
      class={{concatClass
        "chat-message-creator__members-count"
        (if (gte @count @max) "-reached-limit")
      }}
    >
      {{this.countLabel}}
    </div>
  </template>
}
