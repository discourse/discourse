
window.App = Ember.Application.createWithMixins({
  start: function(){
    MessageBus.start();
  }
});

window.App.start();

App.IndexRoute = Ember.Route.extend({
  setupController: function(controller) {
    model =  App.IndexModel.create();
    model.ensureSubscribed();
    controller.set('content', model);
  }
});

App.IndexView = Ember.View.extend({});

App.Process = Ember.View.extend({
  uniqueId: function(){
    return this.get('hostname') + this.get('pid');
  }.property('hostname', 'pid'),

  hup: function(){
    $.post("/message-bus/_diagnostics/hup/" + this.get('hostname') + "/" + this.get('pid'));
  }
});

App.IndexModel = Ember.Object.extend({
  disabled: function(){
    return this.get("discovering") ? "disabled" : null;
  }.property("discovering"),

  ensureSubscribed: function() {
    var processes;
    var _this = this;
    if(this.get("subscribed")) { return; }

    MessageBus.callbackInterval = 500;
    MessageBus.subscribe("/_diagnostics/process-discovery", function(data){
      processes = _this.get('processes');
      processes.pushObject(App.Process.create(data));
      processes = processes.sort(function(a,b){
        return a.get('uniqueId') < b.get('uniqueId') ? -1 : 1;
      });
      // somewhat odd ...
      _this.set('processes', null);
      _this.set('processes', processes);
    });

    this.set("subscribed", true);
  },

  discover: function(){
    var _this = this;
    this.set('processes', Em.A());

    this.ensureSubscribed();

    this.set("discovering", true);
    Ember.run.later(function(){
      _this.set("discovering", false);
    }, 1 * 1000);

    $.post("/message-bus/_diagnostics/discover");
  }
});


App.IndexController = Ember.ObjectController.extend({
  discover: function(){
    this.get("content").discover();
  },

  hup: function(process) {
    process.hup();
  }
});
