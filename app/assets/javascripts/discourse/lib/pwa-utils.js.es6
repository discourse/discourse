export function nativeShare(data) {
  return new Ember.RSVP.Promise((resolve, reject) => {
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
