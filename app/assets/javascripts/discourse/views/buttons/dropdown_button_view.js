/**
  This view handles rendering of a button with an associated drop down

  @class DropdownButtonView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.DropdownButtonView = Discourse.View.extend({
  classNameBindings: [':btn-group', 'hidden'],
  shouldRerender: Discourse.View.renderIfChanged('text', 'longDescription'),

  didInsertElement: function(e) {
    // If there's a click handler, call it
    if (this.clicked) {
      var dropDownButtonView = this;
      this.$('ul li').on('click.dropdown-button', function(e) {
        e.preventDefault();
        dropDownButtonView.clicked($(e.currentTarget).data('id'));
        return false;
      });
    }
  },

  willDestroyElement: function(e) {
    this.$('ul li').off('click.dropdown-button');
  },

  render: function(buffer) {
    buffer.push("<h4 class='title'>" + this.get('title') + "</h4>");
    buffer.push("<button class='btn standard dropdown-toggle' data-toggle='dropdown'>");
    buffer.push(this.get('text'));
    buffer.push("</button>");
    buffer.push("<ul class='dropdown-menu'>");

    _.each(this.get('dropDownContent'), function(row) {
      var id = row[0],
          textKey = row[1],
          title = I18n.t(textKey + ".title"),
          description = I18n.t(textKey + ".description");

      buffer.push("<li data-id=\"" + id + "\"><a href='#'>");
      buffer.push("<span class='title'>" + title + "</span>");
      buffer.push("<span>" + description + "</span>");
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
