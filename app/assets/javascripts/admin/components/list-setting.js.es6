/**
  Provide a nice GUI for a pipe-delimited list in the site settings.

  @param settingValue is a reference to SiteSetting.value.
  @param choices is a reference to SiteSetting.choices
**/
export default Ember.Component.extend({

  _select2FormatSelection: function(selectedObject, jqueryWrapper, htmlEscaper) {
    var text = selectedObject.text;
    if (text.length <= 6) {
      jqueryWrapper.closest('li.select2-search-choice').css({"border-bottom": '7px solid #'+text});
    }
    return htmlEscaper(text);
  },

  _initializeSelect2: function(){
    var options = {
      multiple: false,
      separator: "|",
      tokenSeparators: ["|"],
      tags : this.get("choices") || [],
      width: 'off',
      dropdownCss: this.get("choices") ? {} : {display: 'none'},
      selectOnBlur: this.get("choices") ? false : true
    };

    var settingName = this.get('settingName');
    if (typeof settingName === 'string' && settingName.indexOf('colors') > -1) {
      options.formatSelection = this._select2FormatSelection;
    }

    var self = this;
    this.$("input").select2(options).on("change", function(obj) {
      self.set("settingValue", obj.val.join("|"));
      self.refreshSortables();
    });

    this.refreshSortables();
  }.on('didInsertElement'),

  refreshOnReset: function() {
    this.$("input").select2("val", this.get("settingValue").split("|"));
  }.observes("settingValue"),

  refreshSortables: function() {
    var self = this;
    this.$("ul.select2-choices").sortable().on('sortupdate', function() {
      self.$("input").select2("onSortEnd");
    });
  }
});


