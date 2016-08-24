import Resolver from 'wizard/resolver';
import Router from 'wizard/router';

export default Ember.Application.extend({
  rootElement: '#wizard-main',
  Resolver,
  Router
});
