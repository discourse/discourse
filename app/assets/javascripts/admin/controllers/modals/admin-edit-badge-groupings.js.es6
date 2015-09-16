export default Ember.Controller.extend({
  needs: ['modal'],

  modelChanged: function(){

    var grouping = Em.Object.extend({});

    var model = this.get('model');
    var copy = Em.A();

    if(model){
      model.forEach(function(o){
        copy.pushObject(grouping.create(o));
      });
    }

    this.set('workingCopy', copy);
  }.observes('model'),

  moveItem: function(item, delta){
    var copy = this.get('workingCopy');
    var index = copy.indexOf(item);
    if (index + delta < 0 || index + delta >= copy.length){
      return;
    }

    copy.removeAt(index);
    copy.insertAt(index+delta, item);
  },

  actions: {
    up: function(item){
      this.moveItem(item, -1);
    },
    down: function(item){
      this.moveItem(item, 1);
    },
    "delete": function(item){
      this.get('workingCopy').removeObject(item);
    },
    cancel: function(){
      this.set('model', null);
      this.set('workingCopy', null);
      this.send('closeModal');
    },
    edit: function(item){
      item.set("editing", true);
    },
    save: function(item){
      item.set("editing", false);
    },
    add: function(){
      var obj = Em.Object.create({editing: true, name: "Enter Name"});
      this.get('workingCopy').pushObject(obj);
    },
    saveAll: function(){
      var self = this;
      var items = this.get('workingCopy');
      var groupIds = items.map(function(i){return i.get("id") || -1;});
      var names = items.map(function(i){return i.get("name");});

      Discourse.ajax('/admin/badges/badge_groupings',{
        data: {ids: groupIds, names: names},
        method: 'POST'
      }).then(function(data){
        items = self.get("model");
        items.clear();
        data.badge_groupings.forEach(function(g){
          items.pushObject(Em.Object.create(g));
        });
        self.set('model', null);
        self.set('workingCopy', null);
        self.send('closeModal');
      },function(){
        // TODO we can do better
        bootbox.alert("Something went wrong");
      });
    }
  }
});
