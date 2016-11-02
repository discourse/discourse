import { registerHelper } from 'discourse-common/lib/helpers';

// Note: Later versions of ember include `hash`
registerHelper('as-hash', function(_, params) {
  if (Ember.Helper) { return params; }

  const hash = {};
  Object.keys(params).forEach(k => {
    hash[k] = params[k].value();
  });
  return hash;
});
