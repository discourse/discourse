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


  _select2FormatSelection: function(selectedObject, jqueryWrapper, htmlEscaper) {
    var text = selectedObject.text;
    if (text.length <= 6) {
      jqueryWrapper.closest('li.select2-search-choice').css({"border-bottom": '7px solid #'+text});
    }
    return htmlEscaper(text);
  },

  didInsertElement: function(){

    var select2_options = {
      multiple: false,
      separator: "|",
      tokenSeparators: ["|"],
      tags : this.get("choices") || [],
      width: 'off',
      dropdownCss: this.get("choices") ? {} : {display: 'none'}
    };

    var settingName = this.get('settingName');
    if (typeof settingName === 'string' && settingName.indexOf('colors') > -1) {
      select2_options.formatSelection = this._select2FormatSelection;
    }
    this.$("input").select2(select2_options).on("change", function(obj) {
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


