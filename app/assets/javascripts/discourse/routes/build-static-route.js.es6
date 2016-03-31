import DiscourseRoute from 'discourse/routes/discourse';

export default function(pageName) {
  const route = {
    model() {
      return Discourse.StaticPage.find(pageName);
    },

    renderTemplate() {
      this.render('static');
    },

    setupController(controller, model) {
      this.controllerFor('static').set('model', model);
    }
  };
  return DiscourseRoute.extend(route);
}
