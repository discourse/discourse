import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action, set } from "@ember/object";
import { isBlank, isPresent } from "@ember/utils";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { cook } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import PolicyBuilderForm from "../policy-builder-form";

export default class PolicyBuilder extends Component {
  @tracked isSaving = false;
  @tracked flash;
  policy =
    this.args.model.policy || new TrackedObject({ reminder: null, version: 1 });

  @action
  insertPolicy() {
    if (!this.validateForm()) {
      return;
    }

    this.args.model.toolbarEvent?.addText(
      "\n\n" +
        `[policy ${this.markdownParams}]\n${i18n(
          "discourse_policy.accept_policy_template"
        )}\n[/policy]` +
        "\n\n"
    );
    this.args.closeModal();
  }

  @action
  async updatePolicy() {
    if (!this.validateForm()) {
      return;
    }

    this.isSaving = true;

    try {
      const result = await ajax(`/posts/${this.args.model.post.id}`);
      const newRaw = this.replaceRaw(result.raw);

      if (newRaw) {
        this.args.model.post.save({
          raw: newRaw,
          cooked: (await cook(result.raw)).toString(),
          edit_reason: i18n("discourse_policy.edit_reason"),
        });
      }
    } finally {
      this.isSaving = false;
      this.args.closeModal();
    }
  }

  get markdownParams() {
    const markdownParams = [];
    for (const [key, value] of Object.entries(this.policy)) {
      if (isPresent(value)) {
        markdownParams.push(`${key}="${value}"`);
      }
    }
    return markdownParams.join(" ");
  }

  replaceRaw(raw) {
    const policyRegex = new RegExp(`\\[policy\\s(.*?)\\]`, "m");
    const policyMatches = raw.match(policyRegex);

    if (policyMatches?.[1]) {
      return raw.replace(policyRegex, `[policy ${this.markdownParams}]`);
    }

    return false;
  }

  validateForm() {
    if (isBlank(this.policy.groups)) {
      this.flash = i18n("discourse_policy.builder.errors.group");
      return false;
    }

    if (isBlank(this.policy.version)) {
      this.flash = i18n("discourse_policy.builder.errors.version");
      return false;
    }

    return true;
  }

  <template>
    <DModal
      @title={{i18n "discourse_policy.builder.title"}}
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType="error"
      class="policy-builder"
    >
      <:body>
        <PolicyBuilderForm
          @policy={{this.policy}}
          @onChange={{fn set this.policy}}
        />
      </:body>

      <:footer>
        {{#if @model.insertMode}}
          <DButton
            @label="discourse_policy.builder.insert"
            @action={{this.insertPolicy}}
            class="btn-primary"
          />
        {{else}}
          <DButton
            @label="discourse_policy.builder.save"
            @action={{this.updatePolicy}}
            @isLoading={{this.isSaving}}
            class="btn-primary"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
