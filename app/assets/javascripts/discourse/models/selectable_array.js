// this allows you to track the selected item in an array, ghetto for now
Discourse.SelectableArray = Em.ArrayProxy.extend({

  init: function() {
    this.content = [];
    this._super();
  },

  selectIndex: function(index){
    this.select(this[index]);
  },

  select: function(selected){
    _.each(this.content,function(item){
      if(item === selected){
        Em.set(item, "active", true);
      } else {
        if (item.get("active")) {
          Em.set(item, "active", false);
        }
      }
    });
    this.set("active", selected);
  },

  removeObject: function(object) {
    if(object === this.get("active")){
      this.set("active", null);
      Em.set(object, "active", false);
    }

    this._super(object);
  }

});
