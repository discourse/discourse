import { waitForPromise } from "@ember/test-waiters";

// The create-room modal only opens on a click, but it is reached from an initializer, so a static
// import would put it and everything it pulls in on every page.
export default async function showCreateRoomModal(modal) {
  const { default: VoiceCreateRoomModal } = await waitForPromise(
    import("../../components/modal/voice-create-room")
  );

  modal.show(VoiceCreateRoomModal);
}
