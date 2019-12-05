import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  pluginApiIdentifiers: ["pinned-button"],
  descriptionKey: "help",
  classNames: "pinned-button",
  classNameBindings: ["isHidden"],
  layoutName: "select-kit/templates/components/pinned-button",

  @discourseComputed("topic.pinned_globally", "pinned")
  reasonText(pinnedGlobally, pinned) {
    const globally = pinnedGlobally ? "_globally" : "";
    const pinnedKey = pinned ? `pinned${globally}` : "unpinned";
    const key = `topic_statuses.${pinnedKey}.help`;
    return I18n.t(key);
  },

  @discourseComputed("pinned", "topic.deleted", "topic.unpinned")
  isHidden(pinned, deleted, unpinned) {
    return deleted || (!pinned && !unpinned);
  }
});
