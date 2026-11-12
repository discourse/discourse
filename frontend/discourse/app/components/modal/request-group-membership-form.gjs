/* eslint-disable ember/no-tracked-properties-from-args */
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import withEventValue from "discourse/helpers/with-event-value";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class RequestGroupMembershipForm extends Component {
  @tracked loading = false;
  @tracked reason = this.args.model.group.membership_request_template;

  get title() {
    return i18n("groups.membership_request.title", {
      group_name: this.args.model.group.name,
    });
  }

  get disableSubmit() {
    return this.loading || isEmpty(this.reason);
  }

  @action
  async requestMember() {
    this.loading = true;

    try {
      const result = await this.args.model.group.requestMembership(this.reason);
      DiscourseURL.routeTo(result.relative_url);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      class="request-group-membership-form"
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{this.title}}
    >
      <:body>
        <div class="control-group">
          <label>
            {{i18n "groups.membership_request.reason"}}
          </label>

          <DExpandingTextArea
            maxlength="5000"
            @value={{this.reason}}
            {{on "input" (withEventValue (fn (mut this.reason)))}}
          />
        </div>
      </:body>

      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.requestMember}}
          @disabled={{this.disableSubmit}}
          @label="groups.membership_request.submit"
        />

        <DModalCancel @close={{@closeModal}} />
        <DConditionalLoadingSpinner @condition={{this.loading}} @size="small" />
      </:footer>
    </DModal>
  </template>
}
