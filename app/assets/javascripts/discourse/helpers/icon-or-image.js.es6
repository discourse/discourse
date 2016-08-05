import { htmlHelper } from 'discourse/lib/helpers';

export default htmlHelper(function(str) {
  if (Ember.isEmpty(str)) { return ""; }
  return (str.indexOf('fa-') === 0) ? `<i class='fa ${str}'></i>` : `<img src='${str}'>`;
});
