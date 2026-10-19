import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const MESH_PRIVACY_ACK_KEY = "voice_mesh_privacy_ack";

// Guards against a repeat join request (double click, sidebar plus room
// page) replacing the modal out from under the first one.
let warningOpen = false;

function acknowledged() {
  try {
    return localStorage.getItem(MESH_PRIVACY_ACK_KEY) === "true";
  } catch {
    return false;
  }
}

function rememberAcknowledgement() {
  try {
    localStorage.setItem(MESH_PRIVACY_ACK_KEY, "true");
  } catch {
    // ignore storage errors
  }
}

// Mesh joins connect participants' browsers directly, so everyone in the
// room can learn everyone else's IP address. Resolves to whether the join
// may proceed, gating mesh rooms on an explicit acknowledgement; "don't
// show this again" persists per device.
export async function confirmMeshPrivacy(
  room,
  { currentUser, modal, siteSettings }
) {
  if (
    !siteSettings.voice_mesh_privacy_warning_enabled ||
    !currentUser ||
    room.expected_transport !== "mesh"
  ) {
    return true;
  }

  if (acknowledged()) {
    return true;
  }

  if (warningOpen) {
    return false;
  }

  warningOpen = true;
  try {
    const result = await modal.show(VoiceMeshPrivacyWarningModal);
    if (!result?.join) {
      return false;
    }
    if (result.dontShowAgain) {
      rememberAcknowledgement();
    }
    return true;
  } finally {
    warningOpen = false;
  }
}

// Resolves through `closeModal` with `{ join: true, dontShowAgain }` when the
// user accepts; cancel/escape/backdrop resolve with nothing.
export default class VoiceMeshPrivacyWarningModal extends Component {
  @tracked dontShowAgain = false;

  @action
  updateDontShowAgain(event) {
    this.dontShowAgain = event.target.checked;
  }

  @action
  join() {
    this.args.closeModal({ join: true, dontShowAgain: this.dontShowAgain });
  }

  <template>
    <DModal
      class="voice-mesh-privacy-warning-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "voice.mesh_privacy_warning.title"}}
    >
      <:body>
        <p class="voice-mesh-privacy-warning-modal__body">
          {{i18n "voice.mesh_privacy_warning.body"}}
        </p>
        <label class="voice-mesh-privacy-warning-modal__dont-show-again">
          <input
            checked={{this.dontShowAgain}}
            type="checkbox"
            {{on "change" this.updateDontShowAgain}}
          />
          {{i18n "voice.mesh_privacy_warning.dont_show_again"}}
        </label>
      </:body>
      <:footer>
        <DButton
          class="btn-primary voice-mesh-privacy-warning-modal__join"
          @action={{this.join}}
          @icon="phone"
          @label="voice.mesh_privacy_warning.join"
        />
        <DButton
          class="btn-flat voice-mesh-privacy-warning-modal__cancel"
          @action={{@closeModal}}
          @label="voice.mesh_privacy_warning.cancel"
        />
      </:footer>
    </DModal>
  </template>
}
