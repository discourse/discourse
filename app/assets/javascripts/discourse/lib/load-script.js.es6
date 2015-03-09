export default function loadScript(url) {
  return new Ember.RSVP.Promise(function(resolve) {
    $LAB.script(Discourse.getURL(url)).wait(() => resolve());
  });
}
