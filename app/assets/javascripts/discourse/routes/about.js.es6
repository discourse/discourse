import ShowFooter from "discourse/mixins/show-footer";

export default Discourse.Route.extend(ShowFooter, {
  model: function() {
    return Discourse.ajax("/about.json").then(function(result) {
      return result.about;
    });
  },

  titleToken: function() {
    return I18n.t('about.simple_title');
  }
});
