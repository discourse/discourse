import { CLOSE_STATUS_TYPE } from "discourse/controllers/edit-topic-timer";
import { timeframeDetails } from "select-kit/components/future-date-input-selector";
import Mixin from '@ember/object/mixin';

export default Mixin.create({
  _computeIconsForValue(value) {
    let { icon } = this._updateAt(value);

    if (icon) {
      return icon.split(",");
    }

    return [];
  },

  _computeDatetimeForValue(value) {
    if (Ember.isNone(value)) {
      return null;
    }

    let { time } = this._updateAt(value);
    if (time) {
      let details = timeframeDetails(value);
      if (!details.displayWhen) {
        time = null;
      }
      if (time && details.format) {
        return time.format(details.format);
      }
    }
    return time;
  },

  _updateAt(selection) {
    let details = timeframeDetails(selection);

    if (details) {
      return {
        time: details.when(
          moment(),
          this.statusType !== CLOSE_STATUS_TYPE ? 8 : 18
        ),
        icon: details.icon
      };
    }

    return { time: moment() };
  }
});
