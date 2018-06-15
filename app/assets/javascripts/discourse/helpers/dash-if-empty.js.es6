import { htmlHelper } from "discourse-common/lib/helpers";

export default htmlHelper(str => (Ember.isEmpty(str) ? "&mdash;" : str));
