import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class RewindCallout extends Component {
  @service router;
  @service rewind;

  get showCallout() {
    return this.rewind.active && !this.rewind.dismissed && this.rewind.enabled;
  }

  @action
  openRewind() {
    this.rewind.dismiss();
    this.router.transitionTo("/my/activity/rewind");
  }

  <template>
    {{#if this.showCallout}}
      <div class="rewind-callout__container">
        <DButton
          class="rewind-callout btn-transparent"
          @action={{this.openRewind}}
        >
          <span class="rewind-callout__stack"></span>
          <span class="rewind-callout__title">{{i18n "discourse_rewind.title"}}
            {{this.rewind.fetchRewindYear}}</span>
          <span class="rewind-callout__hand"></span>
        </DButton>
      </div>
    {{/if}}
  </template>
}
