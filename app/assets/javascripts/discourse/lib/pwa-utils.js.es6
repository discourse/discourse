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
          if (e.message === "Share canceled") {
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
