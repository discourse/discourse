import { ajax } from 'discourse/lib/ajax';
export default Discourse.Route.extend({
  model: function() {
    return ajax("/404-body", { dataType: 'html' });
  }
});
