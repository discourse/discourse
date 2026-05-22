import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminUser from "discourse/admin/models/admin-user";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseDebounce from "discourse/lib/debounce";
import { INPUT_DELAY } from "discourse/lib/environment";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const MAX_RESULTS = 6;
const ADMIN_ACTIONS = {
  activate: {
    icon: "user-check",
    labelKey: "admin.dashboard.command_center.actions.activate",
  },
  deactivate: {
    icon: "user-lock",
    labelKey: "admin.dashboard.command_center.actions.deactivate",
  },
  delete: {
    icon: "trash-can",
    labelKey: "admin.dashboard.command_center.actions.delete",
  },
  silence: {
    icon: "volume-xmark",
    labelKey: "admin.dashboard.command_center.actions.silence",
  },
  suspend: {
    icon: "ban",
    labelKey: "admin.dashboard.command_center.actions.suspend",
  },
  unsilence: {
    icon: "volume-high",
    labelKey: "admin.dashboard.command_center.actions.unsilence",
  },
  unsuspend: {
    icon: "unlock",
    labelKey: "admin.dashboard.command_center.actions.unsuspend",
  },
};

export default class AdminCommandCenter extends Component {
  @service adminSearchDataSource;
  @service adminTools;
  @service router;

  @tracked filter = "";
  @tracked searchResults = [];
  @tracked userResults = [];
  @tracked commandPreview = null;
  @tracked commandPreviewLoading = false;
  @tracked loading = false;
  @tracked dataReady = false;
  @tracked continuedConversation = false;

  constructor() {
    super(...arguments);

    this.adminSearchDataSource.buildMap().then(() => {
      this.dataReady = true;

      if (this.hasPanel) {
        this.loading = true;
        this.#performSearch();
      }
    });
  }

  get normalizedFilter() {
    return this.filter.trim().replace(/\s+/g, " ");
  }

  get hasPanel() {
    return this.normalizedFilter.length > 0;
  }

  get showLoadingSpinner() {
    return this.hasPanel && (this.loading || !this.dataReady);
  }

  get showPreviewPrompt() {
    return (
      !this.intentPlan &&
      !this.commandPreview &&
      !this.userResults.length &&
      this.normalizedFilter.length >= 4 &&
      !this.showLoadingSpinner
    );
  }

  get showIntentPlan() {
    return this.intentPlan && !this.commandPreview;
  }

  get showNoSearchResults() {
    return (
      !this.intentPlan &&
      this.hasPanel &&
      !this.userResults.length &&
      !this.topSearchResults.length &&
      !this.showLoadingSpinner
    );
  }

  get topSearchResults() {
    return this.searchResults.slice(0, MAX_RESULTS);
  }

  get shouldSearchUsers() {
    return (
      this.normalizedFilter.length >= 2 &&
      !/\s/.test(this.normalizedFilter) &&
      /^@?[a-z0-9_.-]+(?:@[a-z0-9.-]*)?$/i.test(this.normalizedFilter)
    );
  }

  get intentPlan() {
    if (this.normalizedFilter.length < 4) {
      return null;
    }

    const match = this.normalizedFilter.match(
      /^(?:i\s+want\s+to\s+|please\s+|can\s+you\s+)?(suspend|unsuspend|silence|unsilence|deactivate|activate|delete)\s+(?:user\s+)?@?([a-z0-9_.-]+)$/i
    );

    if (!match) {
      return null;
    }

    const adminAction = match[1].toLowerCase();
    const username = match[2];
    const actionConfig = ADMIN_ACTIONS[adminAction];
    const actionLabel = i18n(actionConfig.labelKey);
    const actionLabelLower = actionLabel.toLowerCase();

    return {
      action: adminAction,
      username,
      icon: actionConfig.icon,
      actionLabel,
      actionLabelLower,
      title: i18n("admin.dashboard.command_center.plan.title"),
      summary: i18n("admin.dashboard.command_center.plan.summary", {
        action: actionLabelLower,
        username,
      }),
      userSearchUrl: `/admin/users/list/active?username=${encodeURIComponent(
        username
      )}`,
    };
  }

  @action
  changeQuery(event) {
    this.filter = event.target.value;
    this.continuedConversation = false;
    this.commandPreview = null;
    this.userResults = [];

    if (this.hasPanel) {
      this.loading = true;
      this.#search();
      this.#searchUsers();
    } else {
      this.searchResults = [];
    }
  }

  @action
  handleInputKeyDown(event) {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      document
        .querySelector(
          ".admin-command-center__panel a, .admin-command-center__panel button"
        )
        ?.focus();
    }

    if (event.key === "Enter" && this.filter) {
      event.preventDefault();
      this.router.transitionTo("adminSearch.index", {
        queryParams: { filter: this.filter },
      });
    }
  }

  @action
  continueConversation() {
    this.continuedConversation = true;
  }

  @action
  async previewCommand() {
    this.commandPreviewLoading = true;

    try {
      this.commandPreview = await ajax("/admin/command-center/preview.json", {
        type: "POST",
        data: { command: this.filter },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.commandPreviewLoading = false;
    }
  }

  @action
  async openSuspendReview() {
    const user = await AdminUser.find(this.commandPreview.user.id);

    this.adminTools.showSuspendModal(user, {
      penalizeUntil: this.commandPreview.suspension.suspend_until,
      reason: this.commandPreview.suspension.reason,
      message: this.commandPreview.suspension.message,
    });
  }

  @action
  openUser(user) {
    this.router.transitionTo("adminUser", user.id, user.username);
  }

  #search() {
    discourseDebounce(this, this.#performSearch, INPUT_DELAY);
  }

  #searchUsers() {
    discourseDebounce(this, this.#performUserSearch, INPUT_DELAY);
  }

  #performSearch() {
    if (!this.hasPanel || !this.dataReady) {
      this.loading = false;
      return;
    }

    this.searchResults = this.adminSearchDataSource.search(this.filter);
    this.loading = false;
  }

  async #performUserSearch() {
    if (!this.shouldSearchUsers) {
      this.userResults = [];
      return;
    }

    const term = this.normalizedFilter;

    try {
      const result = await ajax("/admin/command-center/users.json", {
        data: { term },
      });

      if (term === this.normalizedFilter) {
        this.userResults = result.users || [];
      }
    } catch {
      if (term === this.normalizedFilter) {
        this.userResults = [];
      }
    }
  }

  <template>
    <section
      class="admin-command-center"
      aria-labelledby="admin-command-center-title"
    >
      <div class="admin-command-center__intro">
        <p class="admin-command-center__eyebrow">
          {{i18n "admin.dashboard.command_center.eyebrow"}}
        </p>
        <h1 id="admin-command-center-title">
          {{i18n "admin.dashboard.command_center.title"}}
        </h1>
        <p>{{i18n "admin.dashboard.command_center.subtitle"}}</p>
      </div>

      <div class="admin-command-center__surface">
        <div class="admin-command-center__input-wrap">
          {{dIcon
            "wand-magic-sparkles"
            class="admin-command-center__input-icon"
          }}
          <input
            type="text"
            class="admin-command-center__input"
            value={{this.filter}}
            {{on "input" this.changeQuery}}
            {{on "keydown" this.handleInputKeyDown}}
            placeholder={{i18n "admin.dashboard.command_center.placeholder"}}
            aria-label={{i18n "admin.dashboard.command_center.input_label"}}
          />
        </div>

        {{#if this.hasPanel}}
          <div class="admin-command-center__panel">
            <DConditionalLoadingSpinner @condition={{this.showLoadingSpinner}}>
              {{#if this.commandPreview}}
                <div class="admin-command-center__review">
                  <div class="admin-command-center__plan-heading">
                    {{dIcon "ban"}}
                    <div>
                      <p>{{i18n
                          "admin.dashboard.command_center.review.title"
                        }}</p>
                      <h2>
                        {{i18n
                          "admin.dashboard.command_center.review.summary"
                          username=this.commandPreview.user.username
                          duration=this.commandPreview.suspension.duration
                        }}
                      </h2>
                    </div>
                  </div>

                  <dl class="admin-command-center__facts">
                    <div>
                      <dt>{{i18n
                          "admin.dashboard.command_center.review.trust_level"
                        }}</dt>
                      <dd>{{this.commandPreview.context.trust_level}}</dd>
                    </div>
                    <div>
                      <dt>{{i18n
                          "admin.dashboard.command_center.review.posts"
                        }}</dt>
                      <dd>{{this.commandPreview.context.post_count}}</dd>
                    </div>
                    <div>
                      <dt>{{i18n
                          "admin.dashboard.command_center.review.flags_received"
                        }}</dt>
                      <dd
                      >{{this.commandPreview.context.flags_received_count}}</dd>
                    </div>
                    <div>
                      <dt>{{i18n
                          "admin.dashboard.command_center.review.prior_penalties"
                        }}</dt>
                      <dd
                      >{{this.commandPreview.context.penalty_counts.total}}</dd>
                    </div>
                  </dl>

                  {{#if this.commandPreview.suspension.reason}}
                    <p class="admin-command-center__review-reason">
                      {{i18n
                        "admin.dashboard.command_center.review.reason"
                        reason=this.commandPreview.suspension.reason
                      }}
                    </p>
                  {{/if}}

                  <div class="admin-command-center__actions">
                    <button
                      type="button"
                      class="btn btn-danger"
                      {{on "click" this.openSuspendReview}}
                    >
                      {{i18n
                        "admin.dashboard.command_center.review.open_suspend_modal"
                      }}
                    </button>
                  </div>
                </div>
              {{/if}}

              {{#if this.showIntentPlan}}
                <div class="admin-command-center__plan">
                  <div class="admin-command-center__plan-heading">
                    {{dIcon this.intentPlan.icon}}
                    <div>
                      <p>{{this.intentPlan.title}}</p>
                      <h2>{{this.intentPlan.summary}}</h2>
                    </div>
                  </div>

                  <ol class="admin-command-center__steps">
                    <li>
                      {{i18n
                        "admin.dashboard.command_center.plan.find_user"
                        username=this.intentPlan.username
                      }}
                    </li>
                    <li>
                      {{i18n
                        "admin.dashboard.command_center.plan.review_action"
                        action=this.intentPlan.actionLabelLower
                      }}
                    </li>
                    <li>{{i18n
                        "admin.dashboard.command_center.plan.wait_for_confirmation"
                      }}</li>
                  </ol>

                  <div class="admin-command-center__actions">
                    <button
                      type="button"
                      class="btn btn-primary"
                      disabled={{this.commandPreviewLoading}}
                      {{on "click" this.previewCommand}}
                    >
                      {{i18n
                        "admin.dashboard.command_center.plan.preview_action"
                      }}
                    </button>
                    <a
                      href={{this.intentPlan.userSearchUrl}}
                      class="btn btn-default"
                    >
                      {{i18n "admin.dashboard.command_center.plan.open_user"}}
                    </a>
                    <button
                      type="button"
                      class="btn btn-default admin-command-center__continue"
                      {{on "click" this.continueConversation}}
                    >
                      {{i18n "admin.dashboard.command_center.plan.continue"}}
                    </button>
                  </div>

                  {{#if this.continuedConversation}}
                    <div class="admin-command-center__conversation">
                      <p>{{i18n
                          "admin.dashboard.command_center.conversation.title"
                        }}</p>
                      <div class="admin-command-center__conversation-row">
                        <span>{{i18n
                            "admin.dashboard.command_center.conversation.assistant"
                          }}</span>
                        <p>
                          {{i18n
                            "admin.dashboard.command_center.conversation.reply"
                            action=this.intentPlan.actionLabelLower
                            username=this.intentPlan.username
                          }}
                        </p>
                      </div>
                    </div>
                  {{/if}}
                </div>
              {{/if}}

              {{#if this.showPreviewPrompt}}
                <div class="admin-command-center__ai-fallback">
                  <p>{{i18n "admin.dashboard.command_center.ai_fallback"}}</p>
                  <button
                    type="button"
                    class="btn btn-default"
                    disabled={{this.commandPreviewLoading}}
                    {{on "click" this.previewCommand}}
                  >
                    {{i18n
                      "admin.dashboard.command_center.plan.preview_action"
                    }}
                  </button>
                </div>
              {{/if}}

              {{#if this.userResults}}
                <div class="admin-command-center__users">
                  <p class="admin-command-center__section-label">
                    {{i18n "admin.dashboard.command_center.users.title"}}
                  </p>
                  {{#each this.userResults as |user|}}
                    <button
                      type="button"
                      class="admin-command-center__user"
                      {{on "click" (fn this.openUser user)}}
                    >
                      {{dIcon "user"}}
                      <span>
                        <strong>{{user.username}}</strong>
                        {{#if user.name}}
                          <small>{{user.name}}</small>
                        {{/if}}
                      </span>
                      {{#if user.suspended}}
                        <em>{{i18n
                            "admin.dashboard.command_center.users.suspended"
                          }}</em>
                      {{else if user.silenced}}
                        <em>{{i18n
                            "admin.dashboard.command_center.users.silenced"
                          }}</em>
                      {{/if}}
                    </button>
                  {{/each}}
                </div>
              {{/if}}

              {{#if this.topSearchResults}}
                <div class="admin-command-center__results">
                  <p class="admin-command-center__section-label">
                    {{i18n "admin.dashboard.command_center.search_results"}}
                  </p>
                  {{#each this.topSearchResults as |result|}}
                    <a
                      href={{result.url}}
                      class="admin-command-center__result"
                      data-result-type={{result.type}}
                    >
                      <span>
                        {{#if result.icon}}
                          {{dIcon result.icon}}
                        {{/if}}
                        {{result.label}}
                      </span>
                      {{#if result.description}}
                        <small>{{result.description}}</small>
                      {{/if}}
                    </a>
                  {{/each}}
                </div>
              {{else if this.showNoSearchResults}}
                <p class="admin-command-center__empty">
                  {{i18n
                    "admin.dashboard.command_center.no_search_results"
                    filter=this.filter
                  }}
                </p>
              {{/if}}
            </DConditionalLoadingSpinner>
          </div>
        {{/if}}
      </div>
    </section>
  </template>
}
