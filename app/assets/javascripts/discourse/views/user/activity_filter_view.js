(function() {

  window.Discourse.ActivityFilterView = Em.View.extend(Discourse.Presence, {
    tagName: 'li',
    classNameBindings: ['active'],
    active: (function() {
      var content;
      if (content = this.get('content')) {
        return parseInt(this.get('controller.content.streamFilter'), 10) === parseInt(Em.get(content, 'action_type'), 10);
      } else {
        return this.blank('controller.content.streamFilter');
      }
    }).property('controller.content.streamFilter', 'content.action_type'),
    render: function(buffer) {
      var content, count, description;
      if (content = this.get('content')) {
        count = Em.get(content, 'count');
        description = Em.get(content, 'description');
      } else {
        count = this.get('count');
        description = Em.String.i18n("user.filters.all");
      }
      return buffer.push("<a href='#'>" + description + " <span class='count'>(" + count + ")</span><span class='icon-chevron-right'></span></a>");
    },
    click: function() {
      this.get('controller.content').filterStream(this.get('content.action_type'));
      return false;
    }
  });

}).call(this);
