import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import TopicNotificationsTracking from "discourse/components/topic-notifications-tracking";

export default class TopicNotificationsTrackingExample extends Component {
  @tracked levelId = 1;

  @action
  onChange(levelId) {
    this.levelId = levelId;
  }

  <template>
    <TopicNotificationsTracking
      @levelId={{this.levelId}}
      @onChange={{this.onChange}}
    />
  </template>
}
