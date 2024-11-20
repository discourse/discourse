import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
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
}
