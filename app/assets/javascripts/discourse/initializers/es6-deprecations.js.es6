import DiscourseURL from 'discourse/lib/url';
import Quote from 'discourse/lib/quote';
import debounce from 'discourse/lib/debounce';

function proxyDep(propName, module) {
  if (Discourse.hasOwnProperty(propName)) { return; }
  Object.defineProperty(Discourse, propName, {
    get: function() {
      Ember.warn(`DEPRECATION: \`Discourse.${propName}\` is deprecated, import the module.`);
      return module;
    }
  });
}

export default {
  name: 'es6-deprecations',
  before: 'inject-objects',

  initialize: function() {
    // TODO: Once things have migrated remove these
    proxyDep('computed', require('discourse/lib/computed'));
    proxyDep('Formatter', require('discourse/lib/formatter'));
    proxyDep('URL', DiscourseURL);
    proxyDep('Quote', Quote);
    proxyDep('debounce', debounce);
  }
};
