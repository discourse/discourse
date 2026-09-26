import { lookup } from "discourse/lib/service";
/* eslint-disable ember/no-jquery */
import $ from "jquery";
import SessionService from "discourse/services/session";

//  Append our CSRF token to AJAX requests when necessary.

let installed = false;
let callbacks = $.Callbacks();

export default {
  initialize(owner) {
    // Add a CSRF token to all AJAX requests
    let session = lookup(owner, SessionService);
    session.set(
      "csrfToken",
      document.head.querySelector("meta[name=csrf-token]")?.content
    );

    if (!installed) {
      $.ajaxPrefilter(callbacks.fire);
      installed = true;
    }

    callbacks.add(function (options, originalOptions, xhr) {
      if (!options.crossDomain) {
        xhr.setRequestHeader("X-CSRF-Token", session.get("csrfToken"));
      }
    });
  },

  teardown() {
    callbacks.empty();
  },
};
