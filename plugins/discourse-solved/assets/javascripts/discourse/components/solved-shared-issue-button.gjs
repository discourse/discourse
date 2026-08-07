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
  @service siteSettings;

  @tracked saving = false;

  get show() {
    const topic = this.args.post.topic;
    const hasAcceptedAnswers = topic.accepted_answers?.length > 0;

    return (
      topic.shared_issue_visible &&
      (!hasAcceptedAnswers || this.siteSettings.solved_allow_multiple_solutions)
    );
  }

  get count() {
    return this.args.post.topic.shared_issue_count ?? 0;
  }

  get hasSharedIssue() {
    return this.args.post.topic.user_created_shared_issue;
  }

  get isTopicAuthor() {
    return this.currentUser && this.currentUser.id === this.args.post.user_id;
  }

  get isClosed() {
    return this.args.post.topic.closed;
  }

  get isArchived() {
    return this.args.post.topic.archived;
  }

  get disabled() {
    return (
      this.saving || this.isTopicAuthor || this.isClosed || this.isArchived
    );
  }

  get titleKey() {
    if (this.isTopicAuthor) {
      return "solved.shared_issue.author_title";
    }
    if (this.isClosed) {
      return "solved.shared_issue.closed_title";
    }
    if (this.isArchived) {
      return "solved.shared_issue.archived_title";
    }
    return "solved.shared_issue.title";
  }

  get label() {
    const label = i18n("solved.shared_issue.label");
    if (this.count === 0) {
      return label;
    }
    return i18n("solved.shared_issue.label_with_count", {
      label,
      count: this.count,
    });
  }

  @action
  async toggle() {
    if (this.isTopicAuthor || this.isClosed || this.isArchived) {
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
            (if this.disabled "disabled")
          }}
          ...attributes
          @action={{this.toggle}}
          @disabled={{this.disabled}}
          @icon="hand"
          @translatedLabel={{this.label}}
          @title={{this.titleKey}}
        />
      </div>
    {{/if}}
  </template>
}
