import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import {
  applyTopicLifecycleCallbacks,
  cleanupTopicLifecycleCallbacks,
} from "discourse/lib/topic-lifecycle-callbacks";

export default class CurrentTopic extends Service {
  @service appEvents;
  @service messageBus;

  @tracked topic = null;
  @tracked controller = null;
  @tracked topicController = null;
  @tracked route = null;
  @tracked routeName = null;

  #cleanups = [];

  enter({ topic, controller, topicController = controller, route, routeName }) {
    this.leave();

    this.topic = topic;
    this.controller = controller;
    this.topicController = topicController;
    this.route = route;
    this.routeName = routeName;

    try {
      this.#cleanups = applyTopicLifecycleCallbacks({
        topic,
        controller,
        topicController,
        route,
        routeName,
        appEvents: this.appEvents,
        messageBus: this.messageBus,
        currentTopic: this,
      });
    } catch (error) {
      this.leave();
      throw error;
    }
  }

  leave(topic = null) {
    if (
      topic &&
      this.topic &&
      String(this.topic.id) !== String(topic.id ?? topic)
    ) {
      return;
    }

    const cleanups = this.#cleanups;
    this.#cleanups = [];

    try {
      cleanupTopicLifecycleCallbacks(cleanups);
    } finally {
      this.topic = null;
      this.controller = null;
      this.topicController = null;
      this.route = null;
      this.routeName = null;
    }
  }
}
