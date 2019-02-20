export function share(data) {
  return new Ember.RSVP.Promise((resolve, reject) => {
    if (
      window.location.protocol === "https:" &&
      typeof window.navigator.share !== "undefined"
    ) {
      window.navigator
        .share(data)
        .catch(reject)
        .then(resolve);
    } else {
      reject();
    }
  });
}
