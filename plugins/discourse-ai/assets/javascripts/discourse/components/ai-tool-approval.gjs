import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { capitalize } from "@ember/string";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const STATUSES = { pending: 0, approved: 1, rejected: 2 };

const ApprovalDetails = <template>
  <div class="ai-tool-approval__summary" ...attributes>
    <span class="ai-tool-approval__label">{{i18n
        "discourse_ai.ai_tool_approval.agent"
      }}</span>
    <span class="ai-tool-approval__value">{{@agentName}}</span>

    {{#if @username}}
      <span class="ai-tool-approval__label">{{i18n
          "discourse_ai.ai_tool_approval.user"
        }}</span>
      <span class="ai-tool-approval__value">@{{@username}}</span>
    {{/if}}

    {{#each @parameters as |param|}}
      <span class="ai-tool-approval__label">{{param.key}}</span>
      <span class="ai-tool-approval__value">{{param.value}}</span>
    {{/each}}
  </div>
</template>;

export default class AiToolApproval extends Component {
  @service a11y;
  @service currentUser;

  @tracked reviewable;
  @tracked loading = true;
  @tracked performing = false;
  @tracked loadError = false;
  @tracked notAuthorized = false;

  get actionLabel() {
    return capitalize((this.reviewable?.tool_name || "").replaceAll("_", " "));
  }

  get isApproved() {
    return this.reviewable?.status === STATUSES.approved;
  }

  get isStaff() {
    return this.currentUser?.staff;
  }

  get isPending() {
    return this.reviewable?.status === STATUSES.pending;
  }

  get isResolved() {
    return this.reviewable && !this.isPending;
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
      this.a11y.announce(this.statusLabel, "polite");
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.performing = false;
    }
  }

  <template>
    <div
      class={{dConcatClass
        "ai-tool-approval"
        (if this.isResolved "--resolved")
      }}
      ...attributes
      {{didInsert this.loadReviewable}}
    >
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
          <details class="ai-tool-approval__details ai-details">
            <summary class="ai-tool-approval__toggle ai-details__summary">
              {{dIcon "chevron-right" class="ai-details__caret --collapsed"}}
              {{dIcon "chevron-down" class="ai-details__caret --expanded"}}
              <span class="ai-tool-approval__title">{{this.actionLabel}}</span>
              <span
                class={{dConcatClass
                  "ai-tool-approval__badge"
                  (if this.isApproved "--approved" "--rejected")
                }}
              >
                {{dIcon (if this.isApproved "check" "xmark")}}
                {{this.statusLabel}}
              </span>
            </summary>
            <ApprovalDetails
              @agentName={{this.reviewable.payload.agent_name}}
              @parameters={{this.toolParameters}}
              @username={{this.targetUsername}}
            />
          </details>
        {{else if this.isPending}}
          <div
            class="ai-tool-approval__title --pending"
          >{{this.actionLabel}}</div>
        {{/if}}

        {{#if this.isPending}}
          <ApprovalDetails
            @agentName={{this.reviewable.payload.agent_name}}
            @parameters={{this.toolParameters}}
            @username={{this.targetUsername}}
          />
        {{/if}}

        {{#if this.isPending}}
          {{#if this.isStaff}}
            <div class="ai-tool-approval__actions">
              <DButton
                class="btn-danger"
                @action={{fn this.performAction "reject"}}
                @icon="xmark"
                @isLoading={{this.performing}}
                @label="discourse_ai.ai_tool_approval.reject"
              />
              <DButton
                class="btn-primary"
                @action={{fn this.performAction "approve"}}
                @icon="check"
                @isLoading={{this.performing}}
                @label="discourse_ai.ai_tool_approval.approve"
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
