import Component from "@glimmer/component";
import { gte } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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
      class={{dConcatClass
        "chat-message-creator__members-count"
        (if (gte @count @max) "-reached-limit")
      }}
    >
      {{this.countLabel}}
    </div>
  </template>
}
