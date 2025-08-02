import EmberObject from "@ember/object";
import Flag from "discourse/lib/flag-targets/flag";
import ActionSummary from "discourse/models/action-summary";

export default class TopicFlag extends Flag {
  title() {
    return "flagging_topic.title";
  }

  targetsTopic() {
    return true;
  }

  customSubmitLabel() {
    return "flagging_topic.notify_action";
  }

  submitLabel() {
    return "flagging_topic.action";
  }

  flagCreatedEvent() {
    return "topic:flag-created";
  }

  flagsAvailable(flagModal) {
    let lookup = EmberObject.create();

    flagModal.args.model.flagModel.actions_summary.forEach((a) => {
      a.flagTopic = flagModal.args.model.flagModel;
      a.actionType = flagModal.site.topicFlagTypeById(a.id);
      lookup.set(a.actionType.name_key, ActionSummary.create(a));
    });
    flagModal.topicActionByName = lookup;

    return flagModal.site.topic_flag_types.filter((item) => {
      return flagModal.args.model.flagModel.actions_summary.some((a) => {
        return a.id === item.id && a.can_act;
      });
    });
  }

  postActionFor(flagModal) {
    return flagModal.topicActionByName[flagModal.selected.name_key];
  }
}
