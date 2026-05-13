import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class ImpersonationNotice extends Component {
  @service currentUser;

  @tracked stopping = false;
  @tracked timeLeft = 0;

  constructor() {
    super(...arguments);
    this.timeLeft = this.calculateTimeLeft();
    this.startCountdown();
  }

  get impersonatedUserName() {
    return this.currentUser.username;
  }

  startCountdown() {
    this.countdown = setInterval(() => {
      this.timeLeft = this.calculateTimeLeft();
      if (this.timeLeft <= 0) {
        this.stopImpersonating();
      }
    }, 1000);
  }

  calculateTimeLeft() {
    return (
      moment(this.currentUser.impersonation_expires_at).diff(
        moment(),
        "minutes"
      ) + 1
    );
  }

  @action
  async stopImpersonating() {
    try {
      this.stopping = true;
      await ajax("/admin/impersonate", {
        type: "DELETE",
      });
      clearInterval(this.countdown);
      DiscourseURL.redirectTo("/");
    } catch (err) {
      popupAjaxError(err);
      this.stopping = false;
    }
  }

  <template>
    <div class="impersonation-notice">
      <div>
        <span>
          {{i18n "impersonation.notice" username=this.impersonatedUserName}}
        </span>
        <span>
          {{i18n "impersonation.time_left" count=this.timeLeft}}
        </span>
      </div>
      <DButton
        @action={{this.stopImpersonating}}
        @isLoading={{this.stopping}}
        @label="impersonation.stop"
        class="btn-danger"
      />
    </div>
  </template>
}
