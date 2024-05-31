import { concat } from "@ember/helper";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";

const UnreadIndicator = <template>
  {{~#if @includeUnreadIndicator~}}
    &nbsp;<span
      title={{i18n "topic.unread_indicator"}}
      class={{concatClass
        "badge badge-notification unread-indicator"
        (concat "indicator-topic-" @topicId)
      }}
      ...attributes
    >
      {{~icon "asterisk"~}}
    </span>
  {{~/if~}}
</template>;

export default UnreadIndicator;
