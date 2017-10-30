import SelectBoxKitRowComponent from "select-box-kit/components/select-box-kit/select-box-kit-row";
import DatetimeMixin from "select-box-kit/components/future-date-input-selector/mixin";
import computed from "ember-addons/ember-computed-decorators";

export default SelectBoxKitRowComponent.extend(DatetimeMixin, {
  layoutName: "select-box-kit/templates/components/future-date-input-selector/future-date-input-selector-row",
  classNames: "future-date-input-selector-row",

  @computed("content.value")
  datetime(value) { return this._computeDatetimeForValue(value); },

  @computed("content.value")
  icon(value) { return this._computeIconForValue(value); }
});
