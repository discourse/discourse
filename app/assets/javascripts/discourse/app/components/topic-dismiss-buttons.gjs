import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DismissReadModal from "discourse/components/modal/dismiss-read";
import { i18n } from "discourse-i18n";

export default class TopicDismissButtons extends Component {
  @service currentUser;
  @service modal;

  get showBasedOnPosition() {
    return this.args.position === "top" || this.args.model.topics.length > 5;
  }

  get dismissLabel() {
    if (this.args.selectedTopics.length === 0) {
      return i18n("topics.bulk.dismiss_button");
    }

    return i18n("topics.bulk.dismiss_button_with_selected", {
      count: this.args.selectedTopics.length,
    });
  }

  get dismissNewLabel() {
    if (this.currentUser?.new_new_view_enabled) {
      return i18n("topics.bulk.dismiss_button");
    }

    if (this.args.selectedTopics.length === 0) {
      return i18n("topics.bulk.dismiss_new");
    }

    return i18n("topics.bulk.dismiss_new_with_selected", {
      count: this.args.selectedTopics.length,
    });
  }

  @action
  dismissReadPosts() {
    this.modal.show(DismissReadModal, {
      model: {
        title: this.args.selectedTopics.length
          ? "topics.bulk.dismiss_read_with_selected"
          : "topics.bulk.dismiss_read",
        count: this.args.selectedTopics.length,
        dismissRead: this.args.dismissRead,
      },
    });
  }

  <template>
    {{~#if this.showBasedOnPosition~}}
      <div class="row dismiss-container-{{@position}}">
        {{~#if @showDismissRead~}}
          <DButton
            @action={{this.dismissReadPosts}}
            @translatedLabel={{this.dismissLabel}}
            @title="topics.bulk.dismiss_tooltip"
            id="dismiss-topics-{{@position}}"
            class="btn-default dismiss-read"
          />
        {{~/if~}}
        {{~#if @showResetNew~}}
          <DButton
            @action={{@resetNew}}
            @translatedLabel={{this.dismissNewLabel}}
            @icon="check"
            id="dismiss-new-{{@position}}"
            class="btn-default dismiss-read"
          />
        {{~/if~}}
      </div>
    {{~/if~}}
  </template>
}
