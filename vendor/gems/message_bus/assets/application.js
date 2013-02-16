
window.App = Ember.Application.createWithMixins({
  start: function(){
    MessageBus.start();
  }
});

window.App.start();

App.IndexRoute = Ember.Route.extend({
  setupController: function(controller) {
    controller.set('content', App.IndexModel.create());
  }
});

App.IndexView = Ember.View.extend({
  
});

App.IndexModel = Ember.Object.extend({
  disabled: function(){
    return this.get("discovering") ? "disabled" : null;
  }.property("discovering"),

  discover: function(){
    var _this = this;

    this.set("discovering", true);
    Ember.run.later(function(){
      _this.set("discovering", false);
    }, 1 * 1000);

    $.post("/message-bus/_diagnostics/discover");

    MessageBus.subscribe("/process-discovery", function(data){
      console.log(data);
    });
     
  }
});


App.IndexController = Ember.ObjectController.extend({
  discover: function(){
    this.get("content").discover();
  }
});
