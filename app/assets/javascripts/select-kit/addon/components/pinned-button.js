import Component from "@ember/component";
import { classNameBindings, classNames } from "@ember-decorators/component";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import { pluginApiIdentifiers } from "select-kit/components/select-kit";

@classNames("pinned-button")
@classNameBindings("isHidden")
@pluginApiIdentifiers("pinned-button")
export default class PinnedButton extends Component {
  descriptionKey = "help";

  @discourseComputed("topic.pinned_globally", "pinned")
  reasonText(pinnedGlobally, pinned) {
    const globally = pinnedGlobally ? "_globally" : "";
    const pinnedKey = pinned ? `pinned${globally}` : "unpinned";
    const key = `topic_statuses.${pinnedKey}.help`;
    return i18n(key);
  }

  @discourseComputed("pinned", "topic.deleted", "topic.unpinned")
  isHidden(pinned, deleted, unpinned) {
    return deleted || (!pinned && !unpinned);
  }
}
