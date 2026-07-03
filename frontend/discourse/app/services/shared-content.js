import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import {
  clearSharedContent,
  readSharedContent,
} from "discourse/lib/share-target";

// Holds content shared into Discourse via the Web Share Target when the user
// chose "Add to a reply". The app boots fresh from the OS share sheet with no
// topic open, so we keep the payload here and inject it into the next reply
// composer that opens (see instance-initializers/share-target.js).
export default class SharedContent extends Service {
  @service appEvents;

  @tracked pending = null;

  // Reads the payload the service worker stashed before redirecting to the
  // `share-target` route. Wrapped here so it can be stubbed in tests.
  readShared() {
    return readSharedContent();
  }

  clearShared() {
    return clearSharedContent();
  }

  get hasPending() {
    return !!this.pending;
  }

  storeForReply({ body, files }) {
    this.pending = { body, files };
  }

  consumeInto(model) {
    if (!this.pending) {
      return;
    }

    const { body, files } = this.pending;
    this.pending = null;

    if (body) {
      model.appendText(body, null, { new_line: true });
    }

    if (files?.length) {
      // The uploader binds its listeners when the editor element is inserted,
      // which happens after `composer:open` fires. Wait for it to be ready.
      this.appEvents.one("composer:uploader-ready", () => {
        this.appEvents.trigger("composer:add-files", files);
      });
    }
  }
}
