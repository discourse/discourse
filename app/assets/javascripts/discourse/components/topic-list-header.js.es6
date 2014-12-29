import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  tagName: 'tr',

  rerenderTriggers: ['order', 'ascending'],

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

  renderColumn: function(buffer, options){
    var className = options.sortable ? "sortable " : "";
    className += options.order || "";

    var sortIcon = "";
    if(this.get("order") === options.order && options.sortable){
      className += " sorting";
      sortIcon = " <i class='fa fa-chevron-" + (this.get('ascending') ? 'up' : 'down') +  "'></i>";
    }

    if(options.number){
      className += " num";
    }

    buffer.push("<th data-sort-order='" + options.order + "' class='"+ className +"'>" + I18n.t(options.name) + sortIcon + "</th>");
  },

  renderString: function(buffer){
    var self = this;

    if(this.get('currentUser')){
      buffer.push("<th class='star'>");
      if(this.get('canBulkSelect')){
        var title = I18n.t('topics.bulk.toggle');
        buffer.push("<button class='btn bulk-select' title='" + title + "'><i class='fa fa-list'></i></button>");
      }
      buffer.push("</th>");
    }

    var column = function(options){
      self.renderColumn(buffer, options);
    };

    column({name: 'topic.title', sortable: false, order: 'default'});

    if(!this.get('hideCategory')) {
      column({name: 'category_title', sortable: true, order: 'category'});
    }

    column({sortable: false, order: 'posters', name: 'users'});
    column({sortable: true, order: 'posts', name: 'posts', number: true});
    column({sortable: true, order: 'views', name: 'views', number: true});
    column({sortable: true, order: 'activity', name: 'activity', number: true});
  }

});
