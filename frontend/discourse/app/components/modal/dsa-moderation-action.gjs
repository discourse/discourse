import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DsaModeration from "discourse/components/dsa-moderation";
import { extractError } from "discourse/lib/ajax-error";
import DInterpolatedTranslation from "discourse/ui-kit/d-interpolated-translation";
import DModal from "discourse/ui-kit/d-modal";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import { i18n } from "discourse-i18n";

const USER_PROMPTS = {
  delete_user: "review.user_prompts.delete",
  delete_user_block: "review.user_prompts.block",
};

export default class DsaModerationAction extends Component {
  @tracked flash;
  @tracked saving = false;

  get buttonClass() {
    return this.hasActionDetails && !this.#editing
      ? "btn-danger"
      : "btn-primary";
  }

  get buttonLabel() {
    if (this.#editing) {
      return i18n("review.continue_to_editor");
    }
    return this.hasActionDetails
      ? this.args.model.action.label
      : i18n("dsa_statements.save");
  }

  get hasActionDetails() {
    return Boolean(this.args.model.action.confirm_message);
  }

  get userPromptKey() {
    return (
      this.promptUser && USER_PROMPTS[this.args.model.action.server_action]
    );
  }

  get promptUser() {
    const { reviewable } = this.args.model;
    return reviewable?.target_created_by ?? reviewable?.target_user;
  }

  get nextStepLabel() {
    return this.#editing ? this.args.model.action.label : null;
  }

  get title() {
    return this.hasActionDetails || this.#editing
      ? this.args.model.action.label
      : i18n("dsa_statements.title");
  }

  get #editing() {
    return this.args.model.action.client_action === "edit";
  }

  @action
  async submit(data) {
    if (this.saving) {
      return;
    }
    this.saving = true;
    this.flash = null;
    try {
      await this.args.model.perform(data);
      this.args.closeModal();
    } catch (error) {
      this.flash = extractError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <DsaModeration
      @actionStepLabel={{i18n "review.moderation_steps.confirm"}}
      @hasActionDetails={{this.hasActionDetails}}
      @nextStepLabel={{this.nextStepLabel}}
      @onSubmit={{this.submit}}
      @options={{@model.options}}
      as |flow|
    >
      <DModal
        class="dsa-moderation-action"
        ...attributes
        @closeModal={{@closeModal}}
        @dismissable={{not this.saving}}
        @flash={{this.flash}}
        @title={{this.title}}
      >
        <:belowHeader>
          <flow.Steps @disabled={{this.saving}} />
        </:belowHeader>
        <:body>
          <flow.Body>
            <p>
              {{#if this.userPromptKey}}
                <DInterpolatedTranslation
                  @key={{this.userPromptKey}}
                  as |Placeholder|
                >
                  <Placeholder @name="user"><DUserLink
                      class="dsa-moderation-action__user"
                      @ariaLabel={{this.promptUser.username}}
                      @user={{this.promptUser}}
                    >{{dAvatar
                        this.promptUser
                        imageSize="tiny"
                      }}{{this.promptUser.username}}</DUserLink></Placeholder>
                </DInterpolatedTranslation>
              {{else}}
                {{@model.action.confirm_message}}
              {{/if}}
            </p>
          </flow.Body>
        </:body>
        <:footer>
          <flow.Footer
            @cancel={{if @model.action.confirm_message @closeModal}}
            @cancelDisabled={{this.saving}}
            @disabled={{this.saving}}
            @isLoading={{this.saving}}
            @submitClass={{this.buttonClass}}
            @submitLabel={{this.buttonLabel}}
          />
        </:footer>
      </DModal>
    </DsaModeration>
  </template>
}
