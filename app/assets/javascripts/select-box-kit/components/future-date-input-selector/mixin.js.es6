import { iconHTML } from 'discourse-common/lib/icon-library';
import { CLOSE_STATUS_TYPE } from 'discourse/controllers/edit-topic-timer';
import { timeframeDetails } from 'select-box-kit/components/future-date-input-selector';

export default Ember.Mixin.create({
  _computeIconForValue(value) {
    let {icon} = this._updateAt(value);

    if (icon) {
      return icon.split(",").map(i => iconHTML(i)).join(" ");
    }

    return null;
  },

  _computeDatetimeForValue(value) {
    if (Ember.isNone(value)) {
      return null;
    }

    let {time} = this._updateAt(value);
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
        time: details.when(moment(), this.get('statusType') !== CLOSE_STATUS_TYPE ? 8 : 18),
        icon: details.icon
      };
    }

    return { time: moment() };
  },
});
