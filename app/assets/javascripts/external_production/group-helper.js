(function() {
var get = Ember.get, set = Ember.set, EmberHandlebars = Ember.Handlebars;

EmberHandlebars.registerHelper('group', function(options) {
  var data = options.data,
      fn   = options.fn,
      view = data.view,
      childView;

  childView = view.createChildView(Ember._MetamorphView, {
    context: get(view, 'context'),

    template: function(context, options) {
      options.data.insideGroup = true;
      return fn(context, options);
    }
  });

  view.appendChild(childView);
});

})();

