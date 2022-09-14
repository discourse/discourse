import ActionSummary from "discourse/models/action-summary";
import EmberObject from "@ember/object";
import Flag from "discourse/lib/flag-targets/flag";

export default class TopicFlag extends Flag {
  title() {
    return "flagging_topic.title";
  }

  flaggingTopic() {
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

  flagsAvailable(flagController, site, model) {
    let lookup = EmberObject.create();

    model.get("actions_summary").forEach((a) => {
      a.flagTopic = model;
      a.actionType = site.topicFlagTypeById(a.id);
      lookup.set(a.actionType.get("name_key"), ActionSummary.create(a));
    });
    flagController.set("topicActionByName", lookup);

    return site.get("topic_flag_types").filter((item) => {
      return model.get("actions_summary").some((a) => {
        return a.id === item.get("id") && a.can_act;
      });
    });
  }

  postActionFor(controller) {
    return controller.get(
      "topicActionByName." + controller.get("selected.name_key")
    );
  }
}
