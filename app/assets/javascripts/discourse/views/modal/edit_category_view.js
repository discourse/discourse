/**
  A modal view for editing the basic aspects of a category

  @class EditCategoryView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.EditCategoryView = Discourse.ModalBodyView.extend({
  templateName: 'modal/edit_category',
  appControllerBinding: 'Discourse.appController',

  disabled: (function() {
    if (this.get('saving')) return true;
    if (!this.get('category.name')) return true;
    if (!this.get('category.color')) return true;
    return false;
  }).property('category.name', 'category.color'),

  colorStyle: (function() {
    return "background-color: #" + (this.get('category.color')) + "; color: #" + (this.get('category.text_color')) + ";";
  }).property('category.color', 'category.text_color'),

  // background colors are available as a pipe-separated string
  backgroundColors: (function() {
    return Discourse.SiteSettings.category_colors.split("|").map(function(i) { return i.toUpperCase(); });
  }).property('Discourse.SiteSettings.category_colors'),

  // black & white only for foreground colors
  foregroundColors: ['FFFFFF', '000000'],

  title: (function() {
    if (this.get('category.id')) return Em.String.i18n("category.edit_long");
    return Em.String.i18n("category.create");
  }).property('category.id'),

  categoryName: (function() {
    var name = this.get('category.name') || "";
    return name.trim().length > 0 ? name : Em.String.i18n("preview");
  }).property('category.name'),

  buttonTitle: (function() {
    if (this.get('saving')) return Em.String.i18n("saving");
    return this.get('title');
  }).property('title', 'saving'),

  didInsertElement: function() {
    this._super();
    if (this.get('category')) {
      this.set('id', this.get('category.slug'));
    } else {
      this.set('category', Discourse.Category.create({ color: 'AB9364', text_color: 'FFFFFF' }));
    }
  },

  showCategoryTopic: function() {
    $('#discourse-modal').modal('hide');
    Discourse.URL.routeTo(this.get('category.topic_url'));
    return false;
  },

  saveSuccess: function(result) {
    $('#discourse-modal').modal('hide');
    window.location = Discourse.getURL("/category/") + (Discourse.Utilities.categoryUrlId(result.category));
  },

  saveCategory: function() {
    var _this = this;
    this.set('saving', true);
    return this.get('category').save({
      success: function(result) {
        _this.saveSuccess(result);
      },
      error: function(errors) {
        // displays a generic error message when none is sent from the server
        // this might happen when some "after" callbacks throws an exception server-side
        if(errors.length === 0) errors.push(Em.String.i18n("category.creation_error"));
        // display the errors
        _this.displayErrors(errors);
        // not saving anymore
        _this.set('saving', false);
      }
    });
  }

});
