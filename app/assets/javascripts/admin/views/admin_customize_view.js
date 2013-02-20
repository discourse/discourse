/*global Mousetrap:true */
(function() {

  Discourse.AdminCustomizeView = window.Discourse.View.extend({
    templateName: 'admin/templates/customize',
    classNames: ['customize'],
    contentBinding: 'controller.content',
    init: function() {
      this._super();
      return this.set('selected', 'stylesheet');
    },
    headerActive: (function() {
      return this.get('selected') === 'header';
    }).property('selected'),
    stylesheetActive: (function() {
      return this.get('selected') === 'stylesheet';
    }).property('selected'),
    selectHeader: function() {
      return this.set('selected', 'header');
    },
    selectStylesheet: function() {
      return this.set('selected', 'stylesheet');
    },
    didInsertElement: function() {
      var _this = this;
      return Mousetrap.bindGlobal(['meta+s', 'ctrl+s'], function() {
        _this.get('controller').save();
        return false;
      });
    },
    willDestroyElement: function() {
      return Mousetrap.unbindGlobal('meta+s', 'ctrl+s');
    }
  });

}).call(this);
