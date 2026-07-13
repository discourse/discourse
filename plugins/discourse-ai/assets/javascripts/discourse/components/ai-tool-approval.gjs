import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const STATUSES = { pending: 0, approved: 1, rejected: 2 };

export default class AiToolApproval extends Component {
  @service currentUser;

  @tracked reviewable;
  @tracked loading = true;
  @tracked performing = false;
  @tracked loadError = false;
  @tracked notAuthorized = false;
  @tracked expanded = false;

  get isStaff() {
    return this.currentUser?.staff;
  }

  get isPending() {
    return this.reviewable?.status === STATUSES.pending;
  }

  get isResolved() {
    return this.reviewable && !this.isPending;
  }

  // the summary is always visible while pending; once resolved it collapses
  // behind the status header and reveals on expand
  get showDetails() {
    return this.isPending || this.expanded;
  }

  get statusLabel() {
    if (this.reviewable?.status === STATUSES.approved) {
      return i18n("discourse_ai.ai_tool_approval.approved");
    }
    if (this.reviewable?.status === STATUSES.rejected) {
      return i18n("discourse_ai.ai_tool_approval.rejected");
    }
  }

  get toolParameters() {
    const params = this.reviewable?.tool_parameters;
    if (!params || typeof params !== "object") {
      return [];
    }
    return Object.entries(params)
      .filter(([key]) => key !== "username")
      .map(([key, value]) => ({
        key,
        value:
          typeof value === "object" ? JSON.stringify(value) : String(value),
      }));
  }

  get targetUsername() {
    return this.reviewable?.tool_parameters?.username;
  }

  @action
  toggleExpanded() {
    this.expanded = !this.expanded;
  }

  @action
  async loadReviewable() {
    try {
      const response = await ajax(`/review/${this.args.reviewableId}`);
      this.reviewable = response.reviewable;
    } catch (error) {
      const status = error?.jqXHR?.status;
      if (status === 403 || status === 404) {
        // regular users can't see the review queue — show the same
        // "awaiting approval" state they'd get if the fetch had succeeded
        this.notAuthorized = true;
      } else {
        this.loadError = true;
      }
    } finally {
      this.loading = false;
    }
  }

  @action
  async performAction(actionId) {
    if (this.performing || !this.reviewable || !this.args.postId) {
      return;
    }

    this.performing = true;

    try {
      await ajax(`/review/${this.args.reviewableId}/perform/${actionId}`, {
        type: "PUT",
        data: {
          post_id: this.args.postId,
          version: this.reviewable.version,
        },
      });
      this.reviewable = {
        ...this.reviewable,
        status: actionId === "approve" ? STATUSES.approved : STATUSES.rejected,
      };
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.performing = false;
    }
  }

  <template>
    <div {{didInsert this.loadReviewable}} class="ai-tool-approval">
      {{#if this.loading}}
        <span class="ai-tool-approval__status">{{i18n
            "discourse_ai.ai_tool_approval.loading"
          }}</span>
      {{else if this.notAuthorized}}
        <span class="ai-tool-approval__status">{{i18n
            "discourse_ai.ai_tool_approval.awaiting_staff"
          }}</span>
      {{else if this.loadError}}
        <span class="ai-tool-approval__status">{{i18n
            "discourse_ai.ai_tool_approval.load_error"
          }}</span>
      {{else}}
        {{#if this.isResolved}}
          <DButton
            class="btn-flat ai-tool-approval__toggle"
            @icon={{if this.expanded "chevron-down" "chevron-right"}}
            @translatedLabel={{this.statusLabel}}
            @action={{this.toggleExpanded}}
          />
        {{/if}}

        {{#if this.showDetails}}
          <div class="ai-tool-approval__summary">
            <span class="ai-tool-approval__label">{{i18n
                "discourse_ai.ai_tool_approval.agent"
              }}</span>
            <span
              class="ai-tool-approval__value"
            >{{this.reviewable.payload.agent_name}}</span>

            <span class="ai-tool-approval__label">{{i18n
                "discourse_ai.ai_tool_approval.tool"
              }}</span>
            <span
              class="ai-tool-approval__value"
            >{{this.reviewable.tool_name}}</span>

            {{#if this.targetUsername}}
              <span class="ai-tool-approval__label">{{i18n
                  "discourse_ai.ai_tool_approval.user"
                }}</span>
              <span
                class="ai-tool-approval__value"
              >@{{this.targetUsername}}</span>
            {{/if}}

            {{#each this.toolParameters as |param|}}
              <span class="ai-tool-approval__label">{{param.key}}</span>
              <span class="ai-tool-approval__value">{{param.value}}</span>
            {{/each}}
          </div>
        {{/if}}

        {{#if this.isPending}}
          {{#if this.isStaff}}
            <div class="ai-tool-approval__actions">
              <DButton
                class="btn-danger"
                @icon="xmark"
                @label="discourse_ai.ai_tool_approval.reject"
                @isLoading={{this.performing}}
                @action={{fn this.performAction "reject"}}
              />
              <DButton
                class="btn-primary"
                @icon="check"
                @label="discourse_ai.ai_tool_approval.approve"
                @isLoading={{this.performing}}
                @action={{fn this.performAction "approve"}}
              />
            </div>
          {{else}}
            <span class="ai-tool-approval__status">{{i18n
                "discourse_ai.ai_tool_approval.awaiting_staff"
              }}</span>
          {{/if}}
        {{/if}}
      {{/if}}
    </div>
  </template>
}
