import { REPLY } from "discourse/models/composer";

// When content was shared into Discourse and the user chose "Add to a reply",
// inject it into the next reply composer that opens.
export default {
  initialize(owner) {
    const appEvents = owner.lookup("service:app-events");
    const sharedContent = owner.lookup("service:shared-content");

    appEvents.on("composer:open", ({ model }) => {
      if (model?.action === REPLY && sharedContent.hasPending) {
        sharedContent.consumeInto(model);
      }
    });
  },
};
