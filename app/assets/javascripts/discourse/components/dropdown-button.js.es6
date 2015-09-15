import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  classNameBindings: [':btn-group', 'hidden'],
  rerenderTriggers: ['text', 'longDescription'],

  _bindClick: function() {
    // If there's a click handler, call it
    if (this.clicked) {
      const self = this;
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

  renderString(buffer) {
    const title = this.get('title');
    if (title) {
      buffer.push("<h4 class='title'>" + title + "</h4>");
    }

    buffer.push(`<button class='btn standard dropdown-toggle ${this.get('buttonExtraClasses')}' data-toggle='dropdown'>${this.get('text')}</button>`);
    buffer.push("<ul class='dropdown-menu'>");

    const contents = this.get('dropDownContent');
    if (contents) {
      const self = this;
      contents.forEach(function(row) {
        const id = row.id,
              className = (self.get('activeItem') === id ? 'disabled': '');

        buffer.push("<li data-id=\"" + id + "\" class=\"" + className + "\"><a href>");
        buffer.push("<span class='icon " + row.styleClasses + "'></span>");
        buffer.push("<div><span class='title'>" + row.title + "</span>");
        buffer.push("<span>" + row.description + "</span></div>");
        buffer.push("</a></li>");
      });
    }

    buffer.push("</ul>");

    const desc = this.get('longDescription');
    if (desc) {
      buffer.push("<p>");
      buffer.push(desc);
      buffer.push("</p>");
    }
  }
});
