import StringBuffer from 'discourse/mixins/string-buffer';

export default Discourse.View.extend(StringBuffer, {
  classNameBindings: [':btn-group', 'hidden'],
  rerenderTriggers: ['text', 'longDescription'],

  _bindClick: function() {
    // If there's a click handler, call it
    if (this.clicked) {
      var self = this;
      this.$().on('click.dropdown-button', 'ul li', function(e) {
        e.preventDefault();
        if ($(e.currentTarget).data('id') !== self.get('activeItem')) {
          self.clicked($(e.currentTarget).data('id'));
        }
        self.$('.dropdown-toggle').dropdown('toggle');
        return false;
      });
    }
  }.on('didInsertElement'),

  _unbindClick: function() {
    this.$().off('click.dropdown-button', 'ul li');
  }.on('willDestroyElement'),

  renderString: function(buffer) {

    buffer.push("<h4 class='title'>" + this.get('title') + "</h4>");
    buffer.push("<button class='btn standard dropdown-toggle' data-toggle='dropdown'>");
    buffer.push(this.get('text'));
    buffer.push("</button>");
    buffer.push("<ul class='dropdown-menu'>");

    var self = this;
    this.get('dropDownContent').forEach(function(row) {
      var id = row.id,
          title = row.title,
          iconClass = row.styleClasses,
          description = row.description,
          className = (self.get('activeItem') === id ? 'disabled': '');

      buffer.push("<li data-id=\"" + id + "\" class=\"" + className + "\"><a href>");
      buffer.push("<span class='icon " + iconClass + "'></span>");
      buffer.push("<div><span class='title'>" + title + "</span>");
      buffer.push("<span>" + description + "</span></div>");
      buffer.push("</a></li>");
    });

    buffer.push("</ul>");

    var desc = this.get('longDescription');
    if (desc) {
      buffer.push("<p>");
      buffer.push(desc);
      buffer.push("</p>");
    }
  }
});
