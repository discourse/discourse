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

  predefinedColors: ["FFFFFF", "000000", "AECFC6", "836953", "77DD77", "FFB347", "FDFD96", "536878",
      "EC5800", "0096E0", "7C4848", "9AC932", "BA160C", "003366", "B19CD9", "E4717A"],

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
    window.location = "/category/" + (Discourse.Utilities.categoryUrlId(result.category));
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
