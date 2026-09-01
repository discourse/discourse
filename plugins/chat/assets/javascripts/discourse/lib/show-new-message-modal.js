import { waitForPromise } from "@ember/test-waiters";

// The new-message modal pulls in the message creator and its dependencies. It only ever opens on
// user interaction, but it is reached from initializers, so importing it statically puts all of
// that in the bundle every page pays for.
export default async function showNewMessageModal(modal, options) {
  const { default: ChatModalNewMessage } = await waitForPromise(
    import("../components/chat/modal/new-message.gjs")
  );

  modal.show(ChatModalNewMessage, options);
}
