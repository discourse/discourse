import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import ExpandingTextArea from "discourse/components/expanding-text-area";
import withEventValue from "discourse/helpers/with-event-value";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
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
      @title={{this.title}}
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      class="request-group-membership-form"
    >
      <:body>
        <div class="control-group">
          <label>
            {{i18n "groups.membership_request.reason"}}
          </label>

          <ExpandingTextArea
            {{on "input" (withEventValue (fn (mut this.reason)))}}
            value={{this.reason}}
            maxlength="5000"
          />
        </div>
      </:body>

      <:footer>
        <DButton
          @action={{this.requestMember}}
          @label="groups.membership_request.submit"
          @disabled={{this.disableSubmit}}
          class="btn-primary"
        />

        <DModalCancel @close={{@closeModal}} />
        <ConditionalLoadingSpinner @size="small" @condition={{this.loading}} />
      </:footer>
    </DModal>
  </template>
}
