import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";
import DatetimeMixin from "select-kit/components/future-date-input-selector/mixin";
import computed from "ember-addons/ember-computed-decorators";

export default SelectKitRowComponent.extend(DatetimeMixin, {
  layoutName: "select-kit/templates/components/future-date-input-selector/future-date-input-selector-row",
  classNames: "future-date-input-selector-row",

  @computed("computedContent.value")
  datetime(value) { return this._computeDatetimeForValue(value); },

  @computed("computedContent.value")
  icon(value) { return this._computeIconForValue(value); }
});
