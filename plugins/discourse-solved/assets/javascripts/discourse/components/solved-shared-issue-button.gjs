import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class SolvedSharedIssueButton extends Component {
  @service currentUser;
  @service router;

  @tracked saving = false;

  get show() {
    return (
      this.args.post.topic.shared_issue_visible &&
      !this.args.post.topic.accepted_answer
    );
  }

  get count() {
    return this.args.post.topic.shared_issue_count ?? 1;
  }

  get hasSharedIssue() {
    return this.args.post.topic.user_created_shared_issue;
  }

  get isTopicAuthor() {
    return this.currentUser && this.currentUser.id === this.args.post.user_id;
  }

  get disabled() {
    return this.saving || this.isTopicAuthor;
  }

  get label() {
    return i18n("solved.shared_issue.label", { count: this.count });
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
      const result = await ajax("/solution/shared_issue", {
        type: "POST",
        data: { topic_id: topic.id },
      });

      topic.set("shared_issue_count", result.count);
      topic.set("user_created_shared_issue", result.user_created_shared_issue);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  <template>
    {{#if this.show}}
      <div class="solved-shared-issue-row">
        <DButton
          class={{dConcatClass
            "btn-default"
            "post-action-menu__solved-shared-issue"
            (if this.hasSharedIssue "has-shared-issue")
            (if this.isTopicAuthor "disabled")
          }}
          ...attributes
          @action={{this.toggle}}
          @disabled={{this.disabled}}
          @icon="hand"
          @translatedLabel={{this.label}}
          @title={{if
            this.isTopicAuthor
            "solved.shared_issue.author_title"
            "solved.shared_issue.title"
          }}
        />
      </div>
    {{/if}}
  </template>
}
