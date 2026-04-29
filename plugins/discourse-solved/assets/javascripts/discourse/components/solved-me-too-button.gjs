import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { NotificationLevels } from "discourse/lib/notification-levels";
import { i18n } from "discourse-i18n";

export default class SolvedMeTooButton extends Component {
  @service currentUser;
  @service router;

  @tracked saving = false;

  get count() {
    return this.args.post.topic.me_too_count ?? 1;
  }

  get hasMeToo() {
    return this.args.post.topic.user_did_me_too;
  }

  get label() {
    return i18n("solved.me_too.label", { count: this.count });
  }

  @action
  async toggle() {
    if (!this.currentUser) {
      this.router.transitionTo("login");
      return;
    }

    const topic = this.args.post.topic;
    this.saving = true;

    try {
      const result = await ajax("/solution/me_too", {
        type: "POST",
        data: { topic_id: topic.id },
      });

      topic.set("me_too_count", result.count);
      topic.set("user_did_me_too", result.user_did_me_too);

      const currentLevel = topic.details?.notification_level;
      if (
        result.user_did_me_too &&
        (currentLevel == null || currentLevel < NotificationLevels.TRACKING)
      ) {
        await topic.details.updateNotifications(NotificationLevels.TRACKING);
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DButton
      class={{concatClass
        "btn-flat"
        "post-action-menu__solved-me-too"
        (if this.hasMeToo "has-me-too")
      }}
      ...attributes
      @action={{this.toggle}}
      @disabled={{this.saving}}
      @icon="hand"
      @translatedLabel={{this.label}}
      @title="solved.me_too.title"
    />
  </template>
}
