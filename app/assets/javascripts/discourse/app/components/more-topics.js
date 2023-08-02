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

      if (pills.length === 0) {
        return;
      } else if (pills.length === 1) {
        this.singleList = true;
      }

      let preference = this.moreTopicsPreferenceTracking.preference;
      // Scenario where we have a preference, but there
      // are no more elements in it.
      const listPresent = pills.find((pill) => pill.id === preference);

      if (!listPresent) {
        const rememberPref = this.site.mobileView && !this.singleList;

        this.moreTopicsPreferenceTracking.updatePreference(
          pills[0].id,
          rememberPref
        );
        preference = pills[0].id;
      }

      pills.forEach((pill) => {
        pill.selected = pill.id === preference;
      });

      this.availablePills = pills;
    });
  }
}
