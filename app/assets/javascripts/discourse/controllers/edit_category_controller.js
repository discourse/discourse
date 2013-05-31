/**
  Modal for editing / creating a category

  @class EditCategoryController
  @extends Discourse.ObjectController
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.EditCategoryController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {
  generalSelected:  Ember.computed.equal('selectedTab', 'general'),
  securitySelected: Ember.computed.equal('selectedTab', 'security'),
  settingsSelected: Ember.computed.equal('selectedTab', 'settings'),
  foregroundColors: ['FFFFFF', '000000'],

  descriptionChanged: function() {
    if (this.present('description')) {
      this.set('controllers.modal.modalClass', 'edit-category-modal full');
    } else {
      this.set('controllers.modal.modalClass', 'edit-category-modal small');
    }
  }.observes('description'),

  title: function() {
    if (this.get('id')) return Em.String.i18n("category.edit_long");
    if (this.get('isUncategorized')) return Em.String.i18n("category.edit_uncategorized");
    return Em.String.i18n("category.create");
  }.property('id'),

  titleChanged: function() {
    this.set('controllers.modal.title', this.get('title'));
  }.observes('title'),

  selectGeneral: function() {
    this.set('selectedTab', 'general');
  },

  selectSecurity: function() {
    this.set('selectedTab', 'security');
  },

  selectSettings: function() {
    this.set('selectedTab', 'settings');
  },

  disabled: function() {
    if (this.get('saving') || this.get('deleting')) return true;
    if (!this.get('name')) return true;
    if (!this.get('color')) return true;
    return false;
  }.property('name', 'color', 'deleting'),

  deleteVisible: function() {
    return (this.get('id') && this.get('topic_count') === 0);
  }.property('id', 'topic_count'),

  deleteDisabled: function() {
    return (this.get('deleting') || this.get('saving') || false);
  }.property('disabled', 'saving', 'deleting'),

  colorStyle: function() {
    return "background-color: #" + (this.get('color')) + "; color: #" + (this.get('text_color')) + ";";
  }.property('color', 'text_color'),

  // background colors are available as a pipe-separated string
  backgroundColors: function() {
    var categories = Discourse.Category.list();
    return Discourse.SiteSettings.category_colors.split("|").map(function(i) { return i.toUpperCase(); }).concat(
                categories.map(function(c) { return c.color.toUpperCase(); }) ).uniq();
  }.property('Discourse.SiteSettings.category_colors'),

  usedBackgroundColors: function() {
    var categories = Discourse.Category.list();

    var currentCat = this.get('model');

    return categories.map(function(c) {
      // If editing a category, don't include its color:
      return (currentCat.get('id') && currentCat.get('color').toUpperCase() === c.color.toUpperCase()) ? null : c.color.toUpperCase();
    }, this).compact();
  }.property('id', 'color'),

  categoryName: function() {
    var name = this.get('name') || "";
    return name.trim().length > 0 ? name : Em.String.i18n("preview");
  }.property('name'),

  buttonTitle: function() {
    if (this.get('saving')) return Em.String.i18n("saving");
    if (this.get('isUncategorized')) return Em.String.i18n("save");
    return (this.get('id') ? Em.String.i18n("category.save") : Em.String.i18n("category.create"));
  }.property('saving', 'id'),

  deleteButtonTitle: function() {
    return Em.String.i18n('category.delete');
  }.property(),

  showCategoryTopic: function() {
    $('#discourse-modal').modal('hide');
    Discourse.URL.routeTo(this.get('topic_url'));
    return false;
  },

  addGroup: function(){
    this.get('model').addGroup(this.get("selectedGroup"));
  },

  removeGroup: function(group){
    // OBVIOUS, Ember treats this as Ember.String, we need a real string here
    group = group + "";
    this.get('model').removeGroup(group);
  },

  saveCategory: function() {
    var categoryController = this;
    this.set('saving', true);


    if( this.get('isUncategorized') ) {
      $.when(
        Discourse.SiteSetting.update('uncategorized_color', this.get('color')),
        Discourse.SiteSetting.update('uncategorized_text_color', this.get('text_color')),
        Discourse.SiteSetting.update('uncategorized_name', this.get('name'))
      ).then(function(result) {
        // success
        $('#discourse-modal').modal('hide');
        // We can't redirect to the uncategorized category on save because the slug
        // might have changed.
        Discourse.URL.redirectTo("/categories");
      }, function(errors) {
        // errors
        if(errors.length === 0) errors.push(Em.String.i18n("category.save_error"));
        categoryController.displayErrors(errors);
        categoryController.set('saving', false);
      });
    } else {
      this.get('model').save().then(function(result) {
        // success
        $('#discourse-modal').modal('hide');
        Discourse.URL.redirectTo("/category/" + Discourse.Category.slugFor(result.category));
      }, function(errors) {
        // errors
        if(errors.length === 0) errors.push(Em.String.i18n("category.creation_error"));
        categoryController.displayErrors(errors);
        categoryController.set('saving', false);
      });
    }
  },

  deleteCategory: function() {
    var categoryController = this;
    this.set('deleting', true);
    $('#discourse-modal').modal('hide');
    bootbox.confirm(Em.String.i18n("category.delete_confirm"), Em.String.i18n("no_value"), Em.String.i18n("yes_value"), function(result) {
      if (result) {
        categoryController.get('category').destroy().then(function(){
          // success
          Discourse.URL.redirectTo("/categories");
        }, function(jqXHR){
          // error
          $('#discourse-modal').modal('show');
          categoryController.displayErrors([Em.String.i18n("category.delete_error")]);
          categoryController.set('deleting', false);
        });
      } else {
        $('#discourse-modal').modal('show');
        categoryController.set('deleting', false);
      }
    });
  }


});