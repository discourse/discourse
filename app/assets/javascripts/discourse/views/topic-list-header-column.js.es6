export default Ember.Object.extend({

  localizedName: function(){
    if(this.forceName){
      return this.forceName;
    }

    return I18n.t(this.name);
  }.property(),

  sortClass: function(){
    return "fa fa-chevron-" + (this.parent.ascending ? "up" : "down");
  }.property(),

  isSorting: function(){
    return this.sortable && this.parent.order === this.order;
  }.property(),

  className: function(){
    var name = [];
    if(this.order){
      name.push(this.order);
    }
    if(this.sortable){
      name.push("sortable");

      if(this.get("isSorting")){
        name.push("sorting");
      }
    }

    if(this.number){
      name.push("num");
    }

    return name.join(' ');
  }.property()
});
