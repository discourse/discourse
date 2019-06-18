import ComboBoxComponent from "select-kit/components/combo-box";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["timezone-input"],
  classNames: "timezone-input",
  allowAutoSelectFirst: false,
  fullWidthOnMobile: true,
  filterable: true,
  allowAny: false,

  @computed
  content() {
    let timezones;

    if (
      moment.locale() !== "en" &&
      typeof moment.tz.localizedNames === "function"
    ) {
      timezones = moment.tz.localizedNames();
    }
    timezones = moment.tz.names();

    return timezones.map(t => {
      return {
        id: t,
        name: t
      };
    });
  }
});
