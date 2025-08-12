import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class ImpersonationNotice extends Component {
  @service currentUser;

  @tracked stopping = false;

  get impersonatedUserName() {
    return this.currentUser.username;
  }

  @action
  async stopImpersonating() {
    try {
      this.stopping = true;
      await ajax("/admin/impersonate", {
        type: "DELETE",
      });
      DiscourseURL.redirectTo("/");
    } catch (err) {
      popupAjaxError(err);
      this.stopping = false;
    }
  }

  <template>
    <div class="impersonation-notice">
      <div>{{i18n
          "impersonation.notice"
          username=this.impersonatedUserName
        }}</div>
      <DButton
        @action={{this.stopImpersonating}}
        @disabled={{this.stopping}}
        @label="impersonation.stop"
        class="btn-danger"
      />
    </div>
  </template>
}
