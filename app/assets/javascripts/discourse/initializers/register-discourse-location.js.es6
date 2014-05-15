export default {
  name: "register-discourse-location",
  initialize: function(container, application) {
    application.register('location:discourse-location', Ember.DiscourseLocation);
  }
};
