import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  tagName: 'tr',

  rerenderTriggers: ['order', 'ascending'],

  rawTemplate: 'components/topic-list-header.raw',

  click: function(e) {
    var target = $(e.target);

    if(target.parents().andSelf().hasClass('bulk-select')){
      this.sendAction('toggleBulkSelect');
    } else {
      var th = target.closest('th.sortable');
      if(th.length > 0) {
        this.sendAction('changeSort', th.data('sort-order'));
      }
    }

  },
});
