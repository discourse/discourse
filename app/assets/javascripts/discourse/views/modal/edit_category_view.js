(function() {

  window.Discourse.EditCategoryView = window.Discourse.ModalBodyView.extend({
    templateName: 'modal/edit_category',
    appControllerBinding: 'Discourse.appController',
    disabled: (function() {
      if (this.get('saving')) {
        return true;
      }
      if (!this.get('category.name')) {
        return true;
      }
      if (!this.get('category.color')) {
        return true;
      }
      return false;
    }).property('category.name', 'category.color'),
    colorStyle: (function() {
      return "background-color: #" + (this.get('category.color')) + ";";
    }).property('category.color'),
    title: (function() {
      if (this.get('category.id')) {
        return "Edit Category";
      } else {
        return "Create Category";
      }
    }).property('category.id'),
    buttonTitle: (function() {
      if (this.get('saving')) {
        return "Saving...";
      } else {
        return this.get('title');
      }
    }).property('title', 'saving'),
    didInsertElement: function() {
      this._super();
      if (this.get('category')) {
        return this.set('id', this.get('category.slug'));
      } else {
        return this.set('category', Discourse.Category.create({
          color: 'AB9364'
        }));
      }
    },
    saveSuccess: function(result) {
      jQuery('#discourse-modal').modal('hide');
      window.location = "/category/" + (Discourse.Utilities.categoryUrlId(result.category));
    },
    saveCategory: function() {
      var _this = this;
      this.set('saving', true);
      return this.get('category').save({
        success: function(result) {
          return _this.saveSuccess(result);
        },
        error: function(errors) {
          _this.displayErrors(errors);
          return _this.set('saving', false);
        }
      });
    }
  });

}).call(this);
