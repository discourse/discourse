import ModalFunctionality from 'discourse/mixins/modal-functionality';
import ObjectController from 'discourse/controllers/object';
import { categoryBadgeHTML } from 'discourse/helpers/category-link';

// Modal for editing / creating a category
export default ObjectController.extend(ModalFunctionality, {
  foregroundColors: ['FFFFFF', '000000'],
  editingPermissions: false,
  selectedTab: null,
  saving: false,
  deleting: false,

  parentCategories: function() {
    return Discourse.Category.list().filter(function (c) {
      return !c.get('parentCategory');
    });
  }.property(),

  // We can change the parent if there are no children
  subCategories: function() {
    if (Em.isEmpty(this.get('model.id'))) { return null; }
    return Discourse.Category.list().filterBy('parent_category_id', this.get('model.id'));
  }.property('model.id'),

  canSelectParentCategory: Em.computed.not('model.isUncategorizedCategory'),

  onShow() {
    this.changeSize();
    this.titleChanged();
  },

  changeSize: function() {
    if (this.present('model.description')) {
      this.set('controllers.modal.modalClass', 'edit-category-modal full');
    } else {
      this.set('controllers.modal.modalClass', 'edit-category-modal small');
    }
  }.observes('model.description'),

  title: function() {
    if (this.get('model.id')) {
      return I18n.t("category.edit_long") + " : " + this.get('model.name');
    }
    return I18n.t("category.create") + (this.get('model.name') ? (" : " + this.get('model.name')) : '');
  }.property('model.id', 'model.name'),

  titleChanged: function() {
    this.set('controllers.modal.title', this.get('title'));
  }.observes('title'),

  disabled: function() {
    if (this.get('saving') || this.get('deleting')) return true;
    if (!this.get('model.name')) return true;
    if (!this.get('model.color')) return true;
    return false;
  }.property('saving', 'model.name', 'model.color', 'deleting'),

  emailInEnabled: Discourse.computed.setting('email_in'),

  deleteDisabled: function() {
    return (this.get('deleting') || this.get('saving') || false);
  }.property('disabled', 'saving', 'deleting'),

  colorStyle: function() {
    return "background-color: #" + this.get('model.color') + "; color: #" + this.get('model.text_color') + ";";
  }.property('model.color', 'model.text_color'),

  categoryBadgePreview: function() {
    const model = this.get('model');
    const c = Discourse.Category.create({
      name: model.get('categoryName'),
      color: model.get('color'),
      text_color: model.get('text_color'),
      parent_category_id: parseInt(model.get('parent_category_id'),10),
      read_restricted: model.get('read_restricted')
    });
    return categoryBadgeHTML(c, {link: false});
  }.property('model.parent_category_id', 'model.categoryName', 'model.color', 'model.text_color'),

  // background colors are available as a pipe-separated string
  backgroundColors: function() {
    const categories = Discourse.Category.list();
    return Discourse.SiteSettings.category_colors.split("|").map(function(i) { return i.toUpperCase(); }).concat(
                categories.map(function(c) { return c.color.toUpperCase(); }) ).uniq();
  }.property('Discourse.SiteSettings.category_colors'),

  usedBackgroundColors: function() {
    const categories = Discourse.Category.list();

    const currentCat = this.get('model');

    return categories.map(function(c) {
      // If editing a category, don't include its color:
      return (currentCat.get('id') && currentCat.get('color').toUpperCase() === c.color.toUpperCase()) ? null : c.color.toUpperCase();
    }, this).compact();
  }.property('model.id', 'model.color'),

  categoryName: function() {
    const name = this.get('name') || "";
    return name.trim().length > 0 ? name : I18n.t("preview");
  }.property('name'),

  buttonTitle: function() {
    if (this.get('saving')) return I18n.t("saving");
    if (this.get('model.isUncategorizedCategory')) return I18n.t("save");
    return (this.get('model.id') ? I18n.t("category.save") : I18n.t("category.create"));
  }.property('saving', 'model.id'),

  deleteButtonTitle: function() {
    return I18n.t('category.delete');
  }.property(),

  showDescription: function() {
    return !this.get('model.isUncategorizedCategory') && this.get('model.id');
  }.property('model.isUncategorizedCategory', 'model.id'),

  showPositionInput: Discourse.computed.setting('fixed_category_positions'),

  actions: {
    showCategoryTopic() {
      this.send('closeModal');
      Discourse.URL.routeTo(this.get('model.topic_url'));
      return false;
    },

    editPermissions() {
      this.set('editingPermissions', true);
    },

    addPermission(group, id) {
      this.get('model').addPermission({group_name: group + "",
                                       permission: Discourse.PermissionType.create({id})});
    },

    removePermission(permission) {
      this.get('model').removePermission(permission);
    },

    saveCategory() {
      const self = this,
          model = this.get('model'),
          parentCategory = Discourse.Category.list().findBy('id', parseInt(model.get('parent_category_id'), 10));

      this.set('saving', true);
      model.set('parentCategory', parentCategory);

      self.set('saving', false);
      this.get('model').save().then(function(result) {
        self.send('closeModal');
        model.setProperties({slug: result.category.slug, id: result.category.id });
        Discourse.URL.redirectTo("/c/" + Discourse.Category.slugFor(model));

      }).catch(function(error) {
        if (error && error.responseText) {
          self.flash($.parseJSON(error.responseText).errors[0], 'error');
        } else {
          self.flash(I18n.t('generic_error'), 'error');
        }
        self.set('saving', false);
      });
    },

    deleteCategory() {
      const self = this;
      this.set('deleting', true);

      this.send('hideModal');
      bootbox.confirm(I18n.t("category.delete_confirm"), I18n.t("no_value"), I18n.t("yes_value"), function(result) {
        if (result) {
          self.get('model').destroy().then(function(){
            // success
            self.send('closeModal');
            Discourse.URL.redirectTo("/categories");
          }, function(error){

            if (error && error.responseText) {
              self.flash($.parseJSON(error.responseText).errors[0]);
            } else {
              self.flash(I18n.t('generic_error'));
            }

            self.send('reopenModal');
            self.displayErrors([I18n.t("category.delete_error")]);
            self.set('deleting', false);
          });
        } else {
          self.send('reopenModal');
          self.set('deleting', false);
        }
      });
    }
  }

});
