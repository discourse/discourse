import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { isPresent } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { cook } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import PolicyBuilderForm from "../policy-builder-form";

const POLICY_MARKDOWN_FIELDS = [
  ["groups", "groups"],
  ["version", "version"],
  ["renew", "renew"],
  ["renewStart", "renew-start"],
  ["reminder", "reminder"],
  ["accept", "accept"],
  ["revoke", "revoke"],
  ["addUsersToGroup", "add-users-to-group"],
];

function policyValue(policy, ...keys) {
  for (const key of keys) {
    const value = policy?.get?.(key) ?? policy?.[key];

    if (isPresent(value)) {
      return value;
    }
  }
}

function isPrivate(value) {
  return value === true || value === "true";
}

function policyToFormData(policy) {
  return {
    groups: policyValue(policy, "groups", "group") ?? "",
    version: policyValue(policy, "version") ?? 1,
    renew: policyValue(policy, "renew") ?? "",
    renewStart: policyValue(policy, "renewStart", "renew-start") ?? "",
    reminder: policyValue(policy, "reminder") ?? null,
    accept: policyValue(policy, "accept") ?? "",
    revoke: policyValue(policy, "revoke") ?? "",
    addUsersToGroup:
      policyValue(policy, "addUsersToGroup", "add-users-to-group") ?? "",
    private: isPrivate(policy?.get?.("private") ?? policy?.private),
  };
}

export default class PolicyBuilder extends Component {
  @tracked isSaving = false;
  formApi;

  @cached
  get formData() {
    return policyToFormData(this.args.model.policy);
  }

  @action
  onRegisterApi(api) {
    this.formApi = api;
  }

  @action
  submitForm() {
    this.formApi?.submit();
  }

  @action
  async onSubmit(data) {
    if (this.args.model.insertMode) {
      this.insertPolicy(data);
    } else {
      await this.updatePolicy(data);
    }
  }

  insertPolicy(data) {
    this.args.model.toolbarEvent?.addText(
      "\n\n" +
        `[policy ${this.markdownParams(data)}]\n${i18n(
          "discourse_policy.accept_policy_template"
        )}\n[/policy]` +
        "\n\n"
    );
    this.args.closeModal();
  }

  async updatePolicy(data) {
    if (this.args.model.onApply) {
      this.args.model.onApply(data);
      this.args.closeModal();
      return;
    }

    this.isSaving = true;

    try {
      const result = await ajax(`/posts/${this.args.model.post.id}`);
      const newRaw = this.replaceRaw(result.raw, data);

      if (newRaw) {
        const cooked = await cook(newRaw);
        await this.args.model.post.save({
          raw: newRaw,
          cooked: cooked.toString(),
          edit_reason: i18n("discourse_policy.edit_reason"),
        });

        await this.refreshPostPolicyState();
      }
    } finally {
      this.isSaving = false;
      this.args.closeModal();
    }
  }

  markdownParams(data) {
    const markdownParams = [];

    for (const [formKey, markdownKey] of POLICY_MARKDOWN_FIELDS) {
      const value = data[formKey];

      if (isPresent(value)) {
        markdownParams.push(`${markdownKey}="${value}"`);
      }
    }

    if (data.private) {
      markdownParams.push('private="true"');
    }

    return markdownParams.join(" ");
  }

  replaceRaw(raw, data) {
    const policyRegex = new RegExp(`\\[policy\\s(.*?)\\]`, "m");
    const policyMatches = raw.match(policyRegex);

    if (policyMatches?.[1]) {
      return raw.replace(policyRegex, `[policy ${this.markdownParams(data)}]`);
    }

    return false;
  }

  async refreshPostPolicyState() {
    const result = await ajax(`/posts/${this.args.model.post.id}.json`);

    this.args.model.post.setProperties({
      policy_can_accept: result.policy_can_accept,
      policy_can_revoke: result.policy_can_revoke,
      policy_accepted: result.policy_accepted,
      policy_revoked: result.policy_revoked,
      policy_not_accepted_by: result.policy_not_accepted_by || [],
      policy_not_accepted_by_count: result.policy_not_accepted_by_count,
      policy_accepted_by: result.policy_accepted_by || [],
      policy_accepted_by_count: result.policy_accepted_by_count,
      policy_stats: result.policy_stats,
    });
  }

  <template>
    <DModal
      @title={{i18n "discourse_policy.builder.title"}}
      @closeModal={{@closeModal}}
      class="policy-builder"
    >
      <:body>
        <PolicyBuilderForm
          @data={{this.formData}}
          @onSubmit={{this.onSubmit}}
          @onRegisterApi={{this.onRegisterApi}}
        />
      </:body>

      <:footer>
        {{#if @model.insertMode}}
          <DButton
            @label="discourse_policy.builder.insert"
            @action={{this.submitForm}}
            class="btn-primary"
          />
        {{else}}
          <DButton
            @label="discourse_policy.builder.save"
            @action={{this.submitForm}}
            @isLoading={{this.isSaving}}
            class="btn-primary"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
