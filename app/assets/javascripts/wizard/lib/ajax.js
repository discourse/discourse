import { Promise } from "rsvp";
import getUrl from "discourse-common/lib/get-url";
import jQuery from "jquery";
import { run } from "@ember/runloop";

let token;

export function getToken() {
  if (!token) {
    token = document.querySelector('meta[name="csrf-token"]')?.content;
  }

  return token;
}

export function ajax(args) {
  let url;

  if (arguments.length === 2) {
    url = arguments[0];
    args = arguments[1];
  } else {
    url = args.url;
  }

  return new Promise((resolve, reject) => {
    args.headers = { "X-CSRF-Token": getToken() };
    args.success = (data) => run(null, resolve, data);
    args.error = (xhr) => run(null, reject, xhr);
    args.url = getUrl(url);
    jQuery.ajax(args);
  });
}
