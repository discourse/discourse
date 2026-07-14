import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import DModal from "discourse/ui-kit/d-modal";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";

export default class EmbedAuthFlowModal extends Component {
  @tracked waiting = false;

  // Native button click handler — runs synchronously in the same call stack
  // as the user gesture so requestStorageAccess() and window.open() inside
  // onConfirm see a valid user activation token.
  handleConfirm = () => {
    this.args.model.onConfirm();
    if (this.isSignin) {
      // Keep the modal up with a spinner so the user knows the iframe is
      // waiting for them to finish signing in in the popup.
      this.waiting = true;
    } else {
      this.args.closeModal();
    }
  };

  handleCancel = () => {
    if (this.waiting) {
      this.args.model.onCancel?.();
    }
    this.args.closeModal();
  };

  get isStorageAccess() {
    return this.args.model.kind === "storage-access";
  }

  get isSignin() {
    return this.args.model.kind === "signin";
  }

  get title() {
    if (this.waiting) {
      return i18n("embed_mode.signin_flow.waiting_title");
    }
    const key = this.isStorageAccess
      ? "embed_mode.signin_flow.share_session_title"
      : "embed_mode.signin_flow.signin_required_title";
    return i18n(key, { site_name: this.args.model.siteName });
  }

  get message() {
    const key = this.isStorageAccess
      ? "embed_mode.signin_flow.share_session_message"
      : "embed_mode.signin_flow.signin_required_message";
    return i18n(key, { site_name: this.args.model.siteName });
  }

  get confirmLabel() {
    return this.isStorageAccess
      ? i18n("embed_mode.allow_access")
      : i18n("embed_mode.signin_flow.open_signin_tab");
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{this.title}}
      class="embed-auth-flow-modal"
    >
      <:body>
        {{#if this.waiting}}
          <div class="embed-auth-flow-modal__waiting">
            {{dLoadingSpinner size="large"}}
            <p>{{i18n "embed_mode.signin_flow.waiting_message"}}</p>
          </div>
        {{else}}
          <p>{{this.message}}</p>
        {{/if}}
      </:body>
      <:footer>
        {{#unless this.waiting}}
          <button
            type="button"
            class="btn btn-primary"
            {{on "click" this.handleConfirm}}
          >
            {{this.confirmLabel}}
          </button>
        {{/unless}}
        <button
          type="button"
          class="btn btn-default"
          {{on "click" this.handleCancel}}
        >
          {{i18n "embed_mode.signin_flow.cancel"}}
        </button>
      </:footer>
    </DModal>
  </template>
}
