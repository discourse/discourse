/**
  This view handles rendering of a button in a drop down

  @class DropdownButtonView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.DropdownButtonView = Discourse.View.extend({
  classNames: ['btn-group'],
  attributeBindings: ['data-not-implemented'],

  didInsertElement: function(e) {
    var _this = this;
    return this.$('ul li').on('click', function(e) {
      e.preventDefault();
      _this.clicked($(e.currentTarget).data('id'));
      return false;
    });
  },

  clicked: function(id) {
    return null;
  },

  textChanged: (function() {
    return this.rerender();
  }).observes('text', 'longDescription'),

  render: function(buffer) {
    var desc;
    buffer.push("<h4 class='title'>" + (this.get('title')) + "</h4>");
    buffer.push("<button class='btn standard dropdown-toggle' data-toggle='dropdown'>");
    buffer.push(this.get('text'));
    buffer.push("</button>");
    buffer.push("<ul class='dropdown-menu'>");
    this.get('dropDownContent').each(function(row) {
      var description, id, textKey, title;
      id = row[0];
      textKey = row[1];
      title = Em.String.i18n("" + textKey + ".title");
      description = Em.String.i18n("" + textKey + ".description");
      buffer.push("<li data-id=\"" + id + "\"><a href='#'>");
      buffer.push("<span class='title'>" + title + "</span>");
      buffer.push("<span>" + description + "</span>");
      return buffer.push("</a></li>");
    });
    buffer.push("</ul>");
    if (desc = this.get('longDescription')) {
      buffer.push("<p>");
      buffer.push(desc);
      return buffer.push("</p>");
    }
  }
});


