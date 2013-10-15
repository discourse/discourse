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

  onShow: function() {
    this.changeSize();
    this.titleChanged();
  },

  changeSize: function() {
    if (this.present('description')) {
      this.set('controllers.modal.modalClass', 'edit-category-modal full');
    } else {
      this.set('controllers.modal.modalClass', 'edit-category-modal small');
    }
  }.observes('description'),

  title: function() {
    if (this.get('id')) {
      return I18n.t("category.edit_long") + " : " + this.get('model.name');
    }
    if (this.get('isUncategorized')){
      return I18n.t("category.edit_uncategorized");
    }
    return I18n.t("category.create") + (this.get('model.name') ? (" : " + this.get('model.name')) : '');
  }.property('id', 'model.name'),

  titleChanged: function() {
    this.set('controllers.modal.title', this.get('title'));
  }.observes('title'),

  disabled: function() {
    if (this.get('saving') || this.get('deleting')) return true;
    if (!this.get('name')) return true;
    if (!this.get('color')) return true;
    return false;
  }.property('saving', 'name', 'color', 'deleting'),

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
    return name.trim().length > 0 ? name : I18n.t("preview");
  }.property('name'),

  buttonTitle: function() {
    if (this.get('saving')) return I18n.t("saving");
    if (this.get('isUncategorized')) return I18n.t("save");
    return (this.get('id') ? I18n.t("category.save") : I18n.t("category.create"));
  }.property('saving', 'id'),

  deleteButtonTitle: function() {
    return I18n.t('category.delete');
  }.property(),

  actions: {

    selectGeneral: function() {
      this.set('selectedTab', 'general');
    },

    selectSecurity: function() {
      this.set('selectedTab', 'security');
    },

    selectSettings: function() {
      this.set('selectedTab', 'settings');
    },

    showCategoryTopic: function() {
      this.send('closeModal');
      Discourse.URL.routeTo(this.get('topic_url'));
      return false;
    },

    editPermissions: function(){
      this.set('editingPermissions', true);
    },

    addPermission: function(group, permission_id){
      this.get('model').addPermission({group_name: group + "", permission: Discourse.PermissionType.create({id: permission_id})});
    },

    removePermission: function(permission){
      this.get('model').removePermission(permission);
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
          categoryController.send('closeModal');
          // We can't redirect to the uncategorized category on save because the slug
          // might have changed.
          Discourse.URL.redirectTo("/categories");
        }, function(errors) {
          // errors
          if(errors.length === 0) errors.push(I18n.t("category.save_error"));
          categoryController.displayErrors(errors);
          categoryController.set('saving', false);
        });
      } else {
        this.get('model').save().then(function(result) {
          // success
          categoryController.send('closeModal');
          Discourse.URL.redirectTo("/category/" + Discourse.Category.slugFor(result.category));
        }, function(errors) {
          // errors
          if(errors.length === 0) errors.push(I18n.t("category.creation_error"));
          categoryController.displayErrors(errors);
          categoryController.set('saving', false);
        });
      }
    },

    deleteCategory: function() {
      var self = this;
      this.set('deleting', true);

      this.send('hideModal');
      bootbox.confirm(I18n.t("category.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          self.get('model').destroy().then(function(){
            // success
            self.send('closeModal');
            Discourse.URL.redirectTo("/categories");
          }, function(jqXHR){
            // error
            self.send('showModal');
            self.displayErrors([I18n.t("category.delete_error")]);
            self.set('deleting', false);
          });
        } else {
          self.send('showModal');
          self.set('deleting', false);
        }
      });
    }
  }

});
