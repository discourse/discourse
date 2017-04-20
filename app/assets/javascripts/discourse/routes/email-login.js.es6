import { ajax } from 'discourse/lib/ajax';
import DiscourseURL from 'discourse/lib/url';

export default Discourse.Route.extend({
  titleToken() {
    return I18n.t('login.logging_in');
  },

  model(params) {
    return new Ember.Object(params);
  },

  afterModel(model) {
    // confirm token here so email clients who crawl URLs don't invalidate the link
    if (model) {
      return ajax({ url: `/session/email-login/${model.token}.json`, dataType: 'json', type: 'PUT' }).then(json => {
        if (json.error) {
          model.set('error', json.error);
        } else {
          DiscourseURL.redirectTo("/");
        }
      });
    }
  }
});
