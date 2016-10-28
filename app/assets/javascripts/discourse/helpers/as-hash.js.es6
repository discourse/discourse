import { registerHelper } from 'discourse-common/lib/helpers';

// Note: Later versions of ember include `hash`
registerHelper('as-hash', function(_, params) {
  if (Ember.Helper) { return params; }

  const hash = {};
  Object.keys(params.hash).forEach(k => {
    hash[k] = params.data.view.getStream(params.hash[k]).value();
  });
  return hash;
});
