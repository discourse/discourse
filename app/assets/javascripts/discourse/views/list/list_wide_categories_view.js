Discourse.ListWideCategoriesView = Discourse.View.extend({

  orderingChanged: function(){
    if (this.get("controller.ordering")) {
      this.enableOrdering();
    } else {
      this.disableOrdering();
    }
  }.observes("controller.ordering"),

  rows: function() {
    return $('#topic-list tbody');
  },

  enableOrdering: function(){
    var self = this;
    Em.run.next(function(){
      self.rows().sortable({handle: '.icon-reorder'}).on('sortupdate',function(evt, data){
        var tr = $(data.item);
        var categoryId = tr.data('category_id');
        var position = self.rows().find('tr').index(tr[0]);
        self.get('controller').moveCategory(categoryId, position);
      });
    });
  },

  disableOrdering: function(){
    this.rows().sortable("destroy").off('sortupdate');
  },

  willDestroyElement: function(){
    this.disableOrdering();
  }

});
