import ComboBoxHeaderComponent from "select-box-kit/components/combo-box/combo-box-header";
import DatetimeMixin from "select-box-kit/components/future-date-input-selector/mixin";
import computed from "ember-addons/ember-computed-decorators";

export default ComboBoxHeaderComponent.extend(DatetimeMixin, {
  layoutName: "select-box-kit/templates/components/future-date-input-selector/future-date-input-selector-header",
  classNames: "future-date-input-selector-header",

  @computed("selectedContent.firstObject.value")
  datetime(value) { return this._computeDatetimeForValue(value); },

  @computed("selectedContent.firstObject.value")
  icon(value) { return this._computeIconForValue(value); }
});
