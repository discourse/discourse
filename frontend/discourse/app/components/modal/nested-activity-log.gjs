import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DModal from "discourse/components/d-modal";
import NestedActivityLogItem from "discourse/components/modal/nested-activity-log/item";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class NestedActivityLog extends Component {
  @tracked loading = true;
  @tracked smallActions = [];

  constructor() {
    super(...arguments);
    this.fetchActivity();
  }

  @action
  async fetchActivity() {
    try {
      const topic = this.args.model.topic;
      const data = await ajax(`/n/${topic.slug}/${topic.id}/activity.json`);
      this.smallActions = data.small_actions || [];
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "nested_replies.activity_log.title"}}
      @closeModal={{@closeModal}}
      class="nested-activity-log-modal"
    >
      <:body>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.smallActions.length}}
            <ul class="nested-activity-log-modal__list">
              {{#each this.smallActions as |sa|}}
                <NestedActivityLogItem
                  @action={{sa}}
                  @topicId={{@model.topic.id}}
                />
              {{/each}}
            </ul>
          {{else}}
            <p class="nested-activity-log-modal__empty">
              {{i18n "nested_replies.activity_log.empty"}}
            </p>
          {{/if}}
        </ConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
