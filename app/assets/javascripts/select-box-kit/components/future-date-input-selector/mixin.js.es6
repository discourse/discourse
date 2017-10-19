import { iconHTML } from 'discourse-common/lib/icon-library';
import { CLOSE_STATUS_TYPE } from 'discourse/controllers/edit-topic-timer';
import {
  LATER_TODAY,
  TOMORROW,
  LATER_THIS_WEEK,
  THIS_WEEKEND,
  NEXT_WEEK,
  TWO_WEEKS,
  NEXT_MONTH,
  FOREVER,
  PICK_DATE_AND_TIME,
  SET_BASED_ON_LAST_POST,
} from "select-box-kit/components/future-date-input-selector";

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
      if (value === LATER_TODAY) {
        time = time.format("h a");
      } else if (value === NEXT_MONTH || value === TWO_WEEKS) {
        time = time.format("MMM D");
      } else {
        time = time.format("ddd, h a");
      }
    }

    if (time && value !== FOREVER) {
      return time;
    }

    return null;
  },

  _updateAt(selection) {
    let time = moment();
    let icon;
    const timeOfDay = this.get('statusType') !== CLOSE_STATUS_TYPE ? 8 : 18;

    switch(selection) {
      case LATER_TODAY:
        time = time.hour(18).minute(0);
        icon = 'moon-o';
        break;
      case TOMORROW:
        time = time.add(1, 'day').hour(timeOfDay).minute(0);
        icon = 'sun-o';
        break;
      case LATER_THIS_WEEK:
        time = time.add(2, 'day').hour(timeOfDay).minute(0);
        icon = 'briefcase';
        break;
      case THIS_WEEKEND:
        time = time.day(6).hour(timeOfDay).minute(0);
        icon = 'bed';
        break;
      case NEXT_WEEK:
        time = time.add(1, 'week').day(1).hour(timeOfDay).minute(0);
        icon = 'briefcase';
        break;
      case TWO_WEEKS:
        time = time.add(2, 'week').hour(timeOfDay).minute(0);
        icon = 'briefcase';
        break;
      case NEXT_MONTH:
        time = time.add(1, 'month').startOf('month').hour(timeOfDay).minute(0);
        icon = 'briefcase';
        break;
      case FOREVER:
        time = time.add(1000, 'year').hour(timeOfDay).minute(0);
        icon = 'gavel';
        break;
      case PICK_DATE_AND_TIME:
        time = null;
        icon = 'calendar-plus-o';
        break;
      case SET_BASED_ON_LAST_POST:
        time = null;
        icon = 'clock-o';
        break;
    }

    return { time, icon };
  },
});
