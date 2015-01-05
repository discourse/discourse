
export default Ember.Component.extend({
  tagName: 'table',
  classNames: ['topic-list'],

  toggleInTitle: function(){
    return !this.get('bulkSelectEnabled') && this.get('canBulkSelect');
  }.property('bulkSelectEnabled'),

  sortable: function(){
    return !!this.get('changeSort');
  }.property(),

  click: function(e){
    var self = this;
    var on = function(sel, callback){
      var target = $(e.target).closest(sel);

      if(target.length === 1){
        callback.apply(self, [target]);
      }
    };

    on('button.bulk-select', function(){
      this.sendAction('toggleBulkSelect');
      this.rerender();
    });

    on('th.sortable', function(e){
      this.sendAction('changeSort', e.data('sort-order'));
      this.rerender();
    });
  }
});
