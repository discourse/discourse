import DiscourseLocation from 'discourse/lib/discourse-location';

export default {
  name: "register-discourse-location",
  after: 'inject-objects',

  initialize: function(container, application) {
    application.register('location:discourse-location', DiscourseLocation);
  }
};
