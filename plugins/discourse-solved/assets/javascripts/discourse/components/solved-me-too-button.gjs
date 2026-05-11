import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
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

  get isTopicAuthor() {
    return this.currentUser && this.currentUser.id === this.args.post.user_id;
  }

  get disabled() {
    return this.saving || this.isTopicAuthor;
  }

  get label() {
    return i18n("solved.me_too.label", { count: this.count });
  }

  @action
  async toggle() {
    if (this.isTopicAuthor) {
      return;
    }

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
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DButton
      class={{dConcatClass
        "btn-default"
        "post-action-menu__solved-me-too"
        (if this.hasMeToo "has-me-too")
        (if this.isTopicAuthor "disabled")
      }}
      ...attributes
      @action={{this.toggle}}
      @disabled={{this.disabled}}
      @icon="hand"
      @translatedLabel={{this.label}}
      @title={{if
        this.isTopicAuthor
        "solved.me_too.author_title"
        "solved.me_too.title"
      }}
    />
  </template>
}
