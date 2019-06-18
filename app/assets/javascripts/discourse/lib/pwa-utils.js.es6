export function nativeShare(data) {
  const caps = Discourse.__container__.lookup("capabilities:main");
  return new Ember.RSVP.Promise((resolve, reject) => {
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
