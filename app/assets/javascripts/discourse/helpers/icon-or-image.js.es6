import { htmlHelper } from 'discourse-common/lib/helpers';
import { iconHTML } from 'discourse-common/lib/icon-library';

export default htmlHelper(function(str) {
  if (Ember.isEmpty(str)) { return ""; }
  return (str.indexOf('fa-') === 0) ? iconHTML(str.replace('fa-', '')) : `<img src='${str}'>`;
});
