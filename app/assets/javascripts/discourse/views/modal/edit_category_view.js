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

  // black & white only for foreground colors
  foregroundColors: ['FFFFFF', '000000'],

  disabled: function() {
    if (this.get('saving') || this.get('deleting')) return true;
    if (!this.get('category.name')) return true;
    if (!this.get('category.color')) return true;
    return false;
  }.property('category.name', 'category.color', 'deleting'),

  deleteVisible: function() {
    return (this.get('category.id') && this.get('category.topic_count') === 0);
  }.property('category.id', 'category.topic_count'),

  deleteDisabled: function() {
    return (this.get('deleting') || this.get('saving') || false);
  }.property('disabled', 'saving', 'deleting'),

  colorStyle: function() {
    return "background-color: #" + (this.get('category.color')) + "; color: #" + (this.get('category.text_color')) + ";";
  }.property('category.color', 'category.text_color'),

  // background colors are available as a pipe-separated string
  backgroundColors: function() {
    return Discourse.SiteSettings.category_colors.split("|").map(function(i) { return i.toUpperCase(); }).concat(
                Discourse.site.categories.map(function(c) { return c.color.toUpperCase(); }) ).uniq();
  }.property('Discourse.SiteSettings.category_colors'),

  usedBackgroundColors: function() {
    return Discourse.site.categories.map(function(c) {
      // If editing a category, don't include its color:
      return (this.get('category.id') && this.get('category.color').toUpperCase() === c.color.toUpperCase()) ? null : c.color.toUpperCase();
    }, this).compact();
  }.property('Discourse.site.categories', 'category.id', 'category.color'),

  title: function() {
    if (this.get('category.id')) return Em.String.i18n("category.edit_long");
    return Em.String.i18n("category.create");
  }.property('category.id'),

  categoryName: function() {
    var name = this.get('category.name') || "";
    return name.trim().length > 0 ? name : Em.String.i18n("preview");
  }.property('category.name'),

  buttonTitle: function() {
    if (this.get('saving')) return Em.String.i18n("saving");
    return (this.get('category.id') ? Em.String.i18n("category.save") : Em.String.i18n("category.create"));
  }.property('saving', 'category.id'),

  deleteButtonTitle: function() {
    return Em.String.i18n('category.delete');
  }.property(),

  didInsertElement: function() {
    this._super();

    if( this.get('category.id') ) {
      this.set('loading', true);
      var categoryView = this;

      // We need the topic_count to be correct, so get the most up-to-date info about this category from the server.
      Discourse.Category.findBySlugOrId( this.get('category.slug') || this.get('category.id') ).then( function(cat) {
        categoryView.set('category', cat);
        Discourse.get('site').updateCategory(cat);
        categoryView.set('id', categoryView.get('category.slug'));
        categoryView.set('loading', false);
      });
    } else {
      this.set('category', Discourse.Category.create({ color: 'AB9364', text_color: 'FFFFFF', hotness: 5 }));
    }
  },

  showCategoryTopic: function() {
    $('#discourse-modal').modal('hide');
    Discourse.URL.routeTo(this.get('category.topic_url'));
    return false;
  },

  saveCategory: function() {
    var categoryView = this;
    this.set('saving', true);
    this.get('category').save().then(function(result) {
      // success
      $('#discourse-modal').modal('hide');
      var url = Discourse.getURL("/category/") + (Discourse.Utilities.categoryUrlId(result.category));
      Discourse.URL.redirectTo(url);
    }, function(errors) {
      // errors
      if(errors.length === 0) errors.push(Em.String.i18n("category.creation_error"));
      categoryView.displayErrors(errors);
      categoryView.set('saving', false);
    });
  },

  deleteCategory: function() {
    var categoryView = this;
    this.set('deleting', true);
    $('#discourse-modal').modal('hide');
    bootbox.confirm(Em.String.i18n("category.delete_confirm"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), function(result) {
      if (result) {
        categoryView.get('category').destroy().then(function(){
          // success
          Discourse.URL.redirectTo(Discourse.getURL("/categories"));
        }, function(jqXHR){
          // error
          $('#discourse-modal').modal('show');
          categoryView.displayErrors([Em.String.i18n("category.delete_error")]);
          categoryView.set('deleting', false);
        });
      } else {
        $('#discourse-modal').modal('show');
        categoryView.set('deleting', false);
      }
    });
  }

});
