Discourse.Group = Discourse.Model.extend({

});

Discourse.Group.reopenClass({
  findAll: function(){
    var list = Discourse.SelectableArray.create();

    list.addObject(Discourse.Group.create({id: 1, name: "all mods", members: ["A","b","c"]}));
    list.addObject(Discourse.Group.create({id: 2, name: "other mods", members: ["A","b","c"]}));

    return list;
  },

  find: function(id) {
    var promise = new Em.Deferred();
   
    setTimeout(function(){
      promise.resolve(Discourse.Group.create({id: 1, name: "all mods", members: ["A","b","c"]}));
    }, 1000);
    
    return promise;
  }
});
