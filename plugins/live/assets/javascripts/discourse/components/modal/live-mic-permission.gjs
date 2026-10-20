import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const PERMISSION_ERROR_NAMES = [
  "NotAllowedError",
  "PermissionDeniedError",
  "SecurityError",
];

// Guards against a repeat join request (double click, sidebar plus room
// page) stacking a second copy of the modal.
let helpOpen = false;

// Tells the user why microphone acquisition failed. A permission failure
// usually means a block saved in the browser's site settings (often from a
// past "deny"), so getUserMedia rejects with no prompt — the modal is the
// only way the user learns what to fix. Other failures (no device, device
// in use) get a toast.
export function reportMicAcquisitionFailure(error, { modal, toasts }) {
  if (PERMISSION_ERROR_NAMES.includes(error?.name)) {
    showMicPermissionHelp(modal);
  } else {
    toasts.error({
      duration: 8000,
      data: { message: i18n("live.room.mic_unavailable") },
    });
  }
}

// Purely educational; resolves once dismissed.
async function showMicPermissionHelp(modal) {
  if (helpOpen) {
    return;
  }

  helpOpen = true;
  try {
    await modal.show(LiveMicPermissionModal);
  } finally {
    helpOpen = false;
  }
}

const LiveMicPermissionModal = <template>
  <DModal
    class="live-mic-permission-modal"
    @closeModal={{@closeModal}}
    @title={{i18n "live.mic_permission.title"}}
  >
    <:body>
      <p class="live-mic-permission-modal__body">
        {{i18n "live.mic_permission.body"}}
      </p>
      <p class="live-mic-permission-modal__instructions">
        {{i18n "live.mic_permission.instructions"}}
      </p>
    </:body>
    <:footer>
      <DButton
        class="btn-primary live-mic-permission-modal__ok"
        @action={{@closeModal}}
        @label="live.mic_permission.ok"
      />
    </:footer>
  </DModal>
</template>;

export default LiveMicPermissionModal;
