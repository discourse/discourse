export default Ember.Controller.extend({
  needs: ['modal'],

  modelChanged: function(){
    const model = this.get('model');
    const copy = Em.A();
    const store = this.store;

    if(model){
      model.forEach(function(o){
        copy.pushObject(store.createRecord('badge-grouping', o));
      });
    }

    this.set('workingCopy', copy);
  }.observes('model'),

  moveItem: function(item, delta){
    const copy = this.get('workingCopy');
    const index = copy.indexOf(item);
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
      const obj = this.store.createRecord('badge-grouping', {editing: true, name: I18n.t('admin.badges.badge_grouping')});
      this.get('workingCopy').pushObject(obj);
    },
    saveAll: function(){
      const self = this;
      var items = this.get('workingCopy');
      const groupIds = items.map(function(i){return i.get("id") || -1;});
      const names = items.map(function(i){return i.get("name");});

      Discourse.ajax('/admin/badges/badge_groupings',{
        data: {ids: groupIds, names: names},
        method: 'POST'
      }).then(function(data){
        items = self.get("model");
        items.clear();
        data.badge_groupings.forEach(function(g){
          items.pushObject(self.store.createRecord('badge-grouping', g));
        });
        self.set('model', null);
        self.set('workingCopy', null);
        self.send('closeModal');
      },function(){
        bootbox.alert(I18n.t('generic_error'));
      });
    }
  }
});
