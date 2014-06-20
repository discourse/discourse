/**
  Provide a nice GUI for a pipe-delimited list in the site settings.

  @param settingValue is a reference to SiteSetting.value.
  @param choices is a reference to SiteSetting.choices

  @class Discourse.ListSettingComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
 **/

Discourse.ListSettingComponent = Ember.Component.extend({
  tagName: 'div',

  didInsertElement: function(){
    this.$("input").select2({
        multiple: false,
        separator: "|",
        tokenSeparators: ["|"],
        tags : this.get("choices") || [],
        width: 'off',
        dropdownCss: this.get("choices") ? {} : {display: 'none'}
      }).on("change", function(obj) {
        this.set("settingValue", obj.val.join("|"));
        this.refreshSortables();
      }.bind(this));

    this.refreshSortables();
  },

  refreshOnReset: function() {
    this.$("input").select2("val", this.get("settingValue").split("|"));
  }.observes("settingValue"),

  refreshSortables: function() {
    this.$("ul.select2-choices").sortable().on('sortupdate', function() {
      this.$("input").select2("onSortEnd");
    }.bind(this));
  }
});


