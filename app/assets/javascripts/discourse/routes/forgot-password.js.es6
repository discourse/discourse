import buildStaticRoute from 'discourse/routes/build-static-route';

const ForgotPasswordRoute = buildStaticRoute('password-reset');

ForgotPasswordRoute.reopen({
  beforeModel() {
    this.replaceWith(this.controllerFor('application').get('loginRequired') ? 'login' : 'discovery').then(e => {
      Ember.run.next(() => e.send('showForgotPassword'));
    });
  },
});

export default ForgotPasswordRoute;
