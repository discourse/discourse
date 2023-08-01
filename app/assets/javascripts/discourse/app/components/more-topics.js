import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import { next } from "@ember/runloop";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class MoreTopics extends Component {
  @service site;
  @service moreTopicsPreferenceTracking;

  @tracked availablePills = [];
  @tracked singleList = false;

  get showTopicListsNav() {
    return this.site.mobileView && !this.singleList;
  }

  @action
  rememberTopicListPreference(value) {
    this.moreTopicsPreferenceTracking.updatePreference(value);

    this.buildListPills();
  }

  @action
  buildListPills() {
    next(() => {
      const pills = Array.from(
        document.querySelectorAll(".more-content-topics")
      ).map((topicList) => {
        return {
          name: topicList.dataset.mobileTitle,
          id: topicList.dataset.listId,
        };
      });

      if (pills.length <= 1) {
        this.singleList = true;
      }

      if (this.singleList || !this.site.mobileView) {
        return;
      }

      let preference = this.moreTopicsPreferenceTracking.preference;

      if (!preference) {
        this.moreTopicsPreferenceTracking.updatePreference(pills[0].id);
        preference = pills[0].id;
      }

      pills.forEach((pill) => {
        pill.selected = pill.id === preference;
      });

      this.availablePills = pills;
    });
  }
}
