export function share(data) {
  return new Ember.RSVP.Promise((resolve, reject) => {
    if (window.location.protocol === "https:" && window.navigator.share) {
      window.navigator
        .share(data)
        .catch(reject)
        .then(resolve);
    } else {
      reject();
    }
  });
}
