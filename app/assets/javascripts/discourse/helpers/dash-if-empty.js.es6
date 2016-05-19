import { htmlHelper } from 'discourse/lib/helpers';

export default htmlHelper(str => Ember.isEmpty(str) ? '&mdash;' : str);
