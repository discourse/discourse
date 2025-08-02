import Component from "@ember/component";
import { set } from "@ember/object";

function assignIfEqual(topic, data) {
  if (topic && topic.id === data.topic_id) {
    set(topic, "assigned_to_user", data.assigned_to);
  }
}

export default class FlaggedTopicListener extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);

    this.messageBus.subscribe("/staff/topic-assignment", (data) => {
      if (this.flaggedTopics) {
        this.flaggedTopics.forEach((ft) => assignIfEqual(ft.topic, data));
      } else {
        assignIfEqual(this.topic, data);
      }
    });
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.messageBus.unsubscribe("/staff/topic-assignment");
  }
}
