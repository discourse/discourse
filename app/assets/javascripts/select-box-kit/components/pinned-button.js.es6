import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  descriptionKey: "help",
  classNames: "pinned-button",
  classNameBindings: ["isHidden"],
  layoutName: "select-box-kit/templates/components/pinned-button",

  @computed("topic.pinned_globally", "topic.pinned")
  reasonText(pinnedGlobally, pinned) {
    const globally = pinnedGlobally ? "_globally" : "";
    const pinnedKey = pinned ? `pinned${globally}` : "unpinned";
    const key = `topic_statuses.${pinnedKey}.help`;
    return I18n.t(key);
  },

  @computed("topic.pinned", "topic.deleted", "topic.unpinned")
  isHidden(pinned, deleted, unpinned) {
    return deleted || (!pinned && !unpinned);
  }
});
