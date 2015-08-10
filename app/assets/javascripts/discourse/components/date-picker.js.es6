/* global Pikaday:true */
import loadScript from "discourse/lib/load-script";

export default Em.Component.extend({
  tagName: "input",
  classNames: ["date-picker"],
  _picker: null,

  _loadDatePicker: function() {
    const self = this,
          input = this.$()[0];

    loadScript("/javascripts/pikaday.js").then(function() {
      self._picker = new Pikaday({
        field: input,
        format: "YYYY-MM-DD",
        defaultDate: moment().add(1, "day").toDate(),
        minDate: new Date(),
        onSelect: function(date) {
          self.set("value", moment(date).format("YYYY-MM-DD"));
        },
      });
    });
  }.on("didInsertElement"),

  _destroy: function() {
    this._picker = null;
  }.on("willDestroyElement"),

});
