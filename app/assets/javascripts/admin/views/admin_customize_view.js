/*global Mousetrap:true */

/**
  A view to handle site customizations

  @class AdminCustomizeView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminCustomizeView = Discourse.View.extend({
  templateName: 'admin/templates/customize',
  classNames: ['customize'],
  selected: 'stylesheet',
  mobile: false,

  stylesheetActive:       Em.computed.equal('selected', 'stylesheet'),
  headerActive:           Em.computed.equal('selected', 'header'),
  topActive:              Em.computed.equal('selected', 'top'),
  footerActive:           Em.computed.equal('selected', 'footer'),
  headTagActive:          Em.computed.equal('selected', 'head_tag'),
  bodyTagActive:          Em.computed.equal('selected', 'body_tag'),

  mobileStylesheetActive: Em.computed.equal('selected', 'mobile_stylesheet'),
  mobileHeaderActive:     Em.computed.equal('selected', 'mobile_header'),
  mobileTopActive:        Em.computed.equal('selected', 'mobile_top'),
  mobileFooterActive:     Em.computed.equal('selected', 'mobile_footer'),

  actions: {
    toggleMobile: function() {
      // auto-select best tab
      var tab = this.get("selected");
      if (/_tag$/.test(tab)) { tab = "stylesheet"; }
      if (this.get("mobile")) { tab = tab.replace("mobile_", ""); }
      else { tab = "mobile_" + tab; }
      this.set("selected", tab);
      // toggle mobile
      this.toggleProperty("mobile");
    },

    select: function(tab) {
      this.set('selected', tab);
    },

    toggleMaximize: function() {
      this.set("maximized", !this.get("maximized"));

      Em.run.scheduleOnce('afterRender', this, function(){
        $('.ace-wrapper').each(function(){
          $(this).data("editor").resize();
        });
      });
    },
  },

  _init: function() {
    var controller = this.get('controller');
    Mousetrap.bindGlobal('mod+s', function() {
      controller.send("save");
      return false;
    });
  }.on("didInsertElement"),

  _cleanUp: function() {
    Mousetrap.unbindGlobal('mod+s');
  }.on("willDestroyElement")

});
