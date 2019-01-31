import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  @computed("model.colors", "onlyOverridden")
  colors(allColors, onlyOverridden) {
    if (onlyOverridden) {
      return allColors.filter(color => color.get("overridden"));
    } else {
      return allColors;
    }
  },

  actions: {
    revert: function(color) {
      color.revert();
    },

    undo: function(color) {
      color.undo();
    },

    copyToClipboard() {
      $(".table.colors").hide();
      let area = $("<textarea id='copy-range'></textarea>");
      $(".table.colors").after(area);
      area.text(this.get("model").schemeJson());
      let range = document.createRange();
      range.selectNode(area[0]);
      window.getSelection().addRange(range);
      let successful = document.execCommand("copy");
      if (successful) {
        this.set(
          "model.savingStatus",
          I18n.t("admin.customize.copied_to_clipboard")
        );
      } else {
        this.set(
          "model.savingStatus",
          I18n.t("admin.customize.copy_to_clipboard_error")
        );
      }

      Ember.run.later(() => {
        this.set("model.savingStatus", null);
      }, 2000);

      window.getSelection().removeAllRanges();

      $(".table.colors").show();
      $(area).remove();
    },

    copy() {
      var newColorScheme = Ember.copy(this.get("model"), true);
      newColorScheme.set(
        "name",
        I18n.t("admin.customize.colors.copy_name_prefix") +
          " " +
          this.get("model.name")
      );
      newColorScheme.save().then(() => {
        this.get("allColors").pushObject(newColorScheme);
        this.replaceRoute("adminCustomize.colors.show", newColorScheme);
      });
    },

    save: function() {
      this.get("model").save();
    },

    destroy: function() {
      const model = this.get("model");
      return bootbox.confirm(
        I18n.t("admin.customize.colors.delete_confirm"),
        I18n.t("no_value"),
        I18n.t("yes_value"),
        result => {
          if (result) {
            model.destroy().then(() => {
              this.get("allColors").removeObject(model);
              this.replaceRoute("adminCustomize.colors");
            });
          }
        }
      );
    }
  }
});
