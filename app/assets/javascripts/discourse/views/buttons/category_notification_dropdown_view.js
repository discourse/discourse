/**
  This view handles rendering of a button with an associated drop down

  @class CategoryNotificationDropdownButtonView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.CategoryNotificationDropdownButtonView = Discourse.View.extend({
  classNameBindings: [':btn-group', 'hidden'],
  shouldRerender: Discourse.View.renderIfChanged('text', 'text'),

  didInsertElement: function() {
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

  willDestroyElement: function() {
    this.$('ul li').off('click.dropdown-button');
  },

  render: function(buffer) {
    buffer.push("<button class='btn standard dropdown-toggle' data-toggle='dropdown'>");
    buffer.push(this.get('text'));
    buffer.push("</button>");
    
    buffer.push("<ul class='notification-dropdown-menu'>");

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
    
  }
});
