
let token;

export function ajax(args) {

  if (!token) {
    token = $('meta[name="csrf-token"]').attr('content');
  }

  return new Ember.RSVP.Promise((resolve, reject) => {
    args.headers = {
      'X-CSRF-Token': token
    };
    args.success = data => Ember.run(null, resolve, data);
    args.error = xhr => Ember.run(null, reject, xhr);
    Ember.$.ajax(args);
  });
}
