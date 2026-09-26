import { lookup } from "discourse/lib/service";
import { REPLY } from "discourse/models/composer";
import AppEventsService from "discourse/services/app-events";
import SharedContentService from "discourse/services/shared-content";

// When content was shared into Discourse and the user chose "Add to a reply",
// inject it into the next reply composer that opens.
export default {
  initialize(owner) {
    const appEvents = lookup(owner, AppEventsService);
    const sharedContent = lookup(owner, SharedContentService);

    appEvents.on("composer:open", ({ model }) => {
      if (model?.action === REPLY && sharedContent.hasPending) {
        sharedContent.consumeInto(model);
      }
    });
  },
};
