// this allows you to track the selected item in an array, ghetto for now
Discourse.SelectableArray = Em.ArrayProxy.extend({
  content: [],
  selectIndex: function(index){
    this.select(this[index]);
  },
  select: function(selected){
    this.content.each(function(item){
      if(item === selected){
        Em.set(item, "active", true)
      } else {
        if (item.get("active")) {
          Em.set(item, "active", false)
        }
      }
    });
    this.set("active", selected);
  }
});
