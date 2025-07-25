import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { and, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/bound-avatar-template";
import icon from "discourse/helpers/d-icon";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import PolicyBuilder from "./modal/policy-builder";

export default class PostPolicy extends Component {
  @service appEvents;
  @service currentUser;
  @service modal;

  @tracked isLoading = false;
  @tracked showNotAccepted = false;

  constructor() {
    super(...arguments);

    this.post?.setProperties({
      policy_accepted_by: this.post?.policy_accepted_by || [],
      policy_not_accepted_by: this.post?.policy_not_accepted_by || [],
    });

    this.appEvents.on("policy:changed", this, "policyChanged");
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("policy:changed", this, "policyChanged");
  }

  get post() {
    return this.args.post;
  }

  get policy() {
    return this.args.policy;
  }

  @bind
  async policyChanged(data) {
    if (data.message.id !== this.post.id) {
      return;
    }

    const stream = data.controller.get("model.postStream");
    const post = stream.findLoadedPost(data.message.id);

    if (post) {
      const result = await ajax(`/posts/${post.id}.json`);

      this.post.setProperties({
        policy_can_accept: result.policy_can_accept,
        policy_can_revoke: result.policy_can_revoke,
        policy_accepted: result.policy_accepted,
        policy_revoked: result.policy_revoked,
        policy_not_accepted_by: result.policy_not_accepted_by || [],
        policy_not_accepted_by_count: result.policy_not_accepted_by_count,
        policy_accepted_by: result.policy_accepted_by || [],
        policy_accepted_by_count: result.policy_accepted_by_count,
      });
    }
  }

  get policyHasUsers() {
    return (
      (this.post?.policy_not_accepted_by_count ||
        0 + this.post?.policy_accepted_by_count ||
        0) > 0
    );
  }

  get acceptButtonClasses() {
    let classes = "accept btn-accept-policy";
    if (!this.post?.policy_accepted || this.post?.policy_revoked) {
      classes += " btn-primary";
    }
    return classes;
  }

  get revokeButtonClasses() {
    let classes = "revoke btn-revoke-policy";
    if (!this.post?.policy_revoked || this.post?.policy_accepted) {
      classes += " btn-danger";
    }
    return classes;
  }

  get remainingAcceptedUsers() {
    return (
      (this.post?.policy_accepted_by_count || 0) -
      (this.post?.policy_accepted_by || []).length
    );
  }

  get acceptedUsers() {
    return this.post?.policy_accepted_by || [];
  }

  get remainingNotAcceptedUsers() {
    return (
      (this.post?.get("policy_not_accepted_by_count") || 0) -
      (this.post?.get("policy_not_accepted_by") || []).length
    );
  }

  get notAcceptedUsers() {
    return this.post?.get("policy_not_accepted_by") || [];
  }

  get canManagePolicy() {
    return (
      this.currentUser &&
      (this.currentUser.staff ||
        this.currentUser.id === this.post?.get("user_id"))
    );
  }

  @action
  revokePolicy() {
    this.post.policy_not_accepted_by.pushObject(this.currentUser);
    this.post.set(
      "policy_not_accepted_by_count",
      this.post.policy_not_accepted_by_count + 1
    );

    const obj = this.post.policy_accepted_by.findBy("id", this.currentUser.id);
    if (obj) {
      this.post.policy_accepted_by.removeObject(obj);
      this.post.set(
        "policy_accepted_by_count",
        this.post.policy_accepted_by_count - 1
      );
    }

    if (this.post.policy_can_accept !== this.post.policy_can_revoke) {
      this.post.setProperties({
        policy_can_accept: true,
        policy_can_revoke: false,
        policy_accepted: false,
        policy_revoked: true,
      });
    }

    this._updatePolicy("unaccept", this.post.id);
  }

  @action
  acceptPolicy() {
    this.post.policy_accepted_by.pushObject(this.currentUser);
    this.post.set(
      "policy_accepted_by_count",
      this.post.policy_accepted_by_count + 1
    );

    const obj = this.post.policy_not_accepted_by.findBy(
      "id",
      this.currentUser.id
    );

    if (obj) {
      this.post.policy_not_accepted_by.removeObject(obj);
      this.post.set(
        "policy_not_accepted_by_count",
        this.post.policy_not_accepted_by_count - 1
      );
    }

    if (this.post.policy_can_accept !== this.post.policy_can_revoke) {
      this.post.setProperties({
        policy_can_accept: false,
        policy_can_revoke: true,
        policy_accepted: true,
        policy_revoked: false,
      });
    }

    this._updatePolicy("accept", this.post.id);
  }

  @action
  async loadRemainingAcceptedUsers(event) {
    event.preventDefault();

    try {
      const result = await ajax(`/policy/accepted`, {
        data: {
          post_id: this.post.id,
          offset: this.post.policy_accepted_by.length,
        },
      });

      result.users.forEach((user) => {
        this.post.policy_accepted_by.pushObject(user);
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async loadRemainingNotAcceptedUsers(event) {
    event.preventDefault();

    try {
      const result = await ajax(`/policy/accepted`, {
        data: {
          post_id: this.post.id,
          offset: this.post.policy_not_accepted_by.length,
        },
      });
      result.users.forEach((user) => {
        this.post.policy_not_accepted_by.pushObject(user);
      });
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  editPolicy() {
    this.modal.show(PolicyBuilder, {
      model: {
        insertMode: false,
        post: this.post,
        policy: this.policy,
      },
    });
  }

  @action
  toggleShowUsers(event) {
    event.preventDefault();
    this.showNotAccepted = !this.showNotAccepted;
  }

  async _updatePolicy(policyAction, id) {
    this.isLoading = true;

    try {
      await ajax(`/policy/${policyAction}`, {
        type: "PUT",
        data: { post_id: id },
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    {{#if this.post}}
      <div class="policy-footer">
        <div class="policy-actions">
          {{#if this.post.policy_can_accept}}
            <DButton
              @isLoading={{this.isLoading}}
              @action={{this.acceptPolicy}}
              class={{this.acceptButtonClasses}}
              @translatedLabel={{this.policy.accept}}
              @icon={{if this.post.policy_accepted "check"}}
            />
          {{/if}}

          {{#if this.post.policy_can_revoke}}
            <DButton
              @isLoading={{this.isLoading}}
              @action={{this.revokePolicy}}
              class={{this.revokeButtonClasses}}
              @translatedLabel={{this.policy.revoke}}
              @icon={{if this.post.policy_revoked "check"}}
            />
          {{/if}}
        </div>

        <div class="user-lists">
          {{#if (and (not this.policyHasUsers) this.post.policy_stats)}}
            <span class="no-possible-users">
              {{i18n "discourse_policy.no_possible_users"}}
            </span>
          {{/if}}

          {{#if this.post.policy_accepted_by_count}}
            <a
              href
              {{on "click" this.toggleShowUsers}}
              title={{i18n "discourse_policy.accepted_tooltip"}}
              class="toggle toggle-accepted"
            >
              <span class="user-count">
                {{this.post.policy_accepted_by_count}}
              </span>
              {{icon "user-check"}}
            </a>

            {{#unless this.showNotAccepted}}
              {{#if this.acceptedUsers.length}}
                <div class="users accepted">
                  {{#each this.acceptedUsers as |acceptedUser|}}
                    {{avatar acceptedUser.avatar_template "tiny"}}
                  {{/each}}

                  {{#if this.remainingAcceptedUsers}}
                    <a
                      href
                      {{on "click" this.loadRemainingAcceptedUsers}}
                      class="load-more-users"
                    >
                      +
                      {{this.remainingAcceptedUsers}}
                      {{icon "user"}}
                    </a>
                  {{/if}}
                </div>
              {{/if}}
            {{/unless}}
          {{/if}}

          {{#if this.post.policy_not_accepted_by_count}}
            <div class="separator"></div>

            <a
              href
              {{on "click" this.toggleShowUsers}}
              title={{i18n "discourse_policy.not_accepted_tooltip"}}
              class="toggle toggle-not-accepted"
            >
              <span class="user-count">
                {{this.post.policy_not_accepted_by_count}}
              </span>
              {{icon "user-xmark"}}
            </a>

            {{#if this.showNotAccepted}}
              <div class="users not-accepted">
                {{#each this.notAcceptedUsers as |notAcceptedUser|}}
                  {{avatar notAcceptedUser.avatar_template "tiny"}}
                {{/each}}

                {{#if this.remainingNotAcceptedUsers}}
                  <a
                    href
                    {{on "click" this.loadRemainingNotAcceptedUsers}}
                    class="load-more-users"
                  >
                    +
                    {{this.remainingNotAcceptedUsers}}
                    {{icon "user"}}
                  </a>
                {{/if}}
              </div>
            {{/if}}
          {{/if}}
        </div>

        {{#if this.canManagePolicy}}
          <DButton
            @action={{this.editPolicy}}
            @icon="gear"
            class="no-text btn-default edit-policy-settings-btn"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
