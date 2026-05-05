import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class EmbedAuthFlowModal extends Component {
  // Native button click handler — runs synchronously in the same call stack
  // as the user gesture so requestStorageAccess() and window.open() inside
  // onConfirm see a valid user activation token.
  handleConfirm = () => {
    this.args.model.onConfirm();
    this.args.closeModal();
  };

  handleCancel = () => {
    this.args.closeModal();
  };

  get isStorageAccess() {
    return this.args.model.kind === "storage-access";
  }

  get title() {
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
        <p>{{this.message}}</p>
      </:body>
      <:footer>
        <button
          type="button"
          class="btn btn-primary"
          {{on "click" this.handleConfirm}}
        >
          {{this.confirmLabel}}
        </button>
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
