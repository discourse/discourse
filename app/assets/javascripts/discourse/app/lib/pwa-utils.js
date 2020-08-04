import { Promise } from "rsvp";

export function nativeShare(data) {
  const caps = Discourse.__container__.lookup("capabilities:main");
  return new Promise((resolve, reject) => {
    if (!(caps.isIOS || caps.isAndroid || caps.isWinphone)) {
      reject();
      return;
    }
    if (
      window.location.protocol === "https:" &&
      typeof window.navigator.share !== "undefined"
    ) {
      window.navigator
        .share(data)
        .then(resolve)
        .catch(e => {
          if (e.name === "AbortError") {
            // closing share panel do nothing
          } else {
            reject();
          }
        });
    } else {
      reject();
    }
  });
}

export function getNativeContact(properties, multiple) {
  const caps = Discourse.__container__.lookup("capabilities:main");
  return new Promise((resolve, reject) => {
    if (!caps.hasContactPicker) {
      reject();
      return;
    }

    navigator.contacts
      .select(properties, { multiple })
      .then(resolve)
      .catch(reject);
  });
}
