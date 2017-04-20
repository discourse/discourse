import { default as computed, observes } from "ember-addons/ember-computed-decorators";
import Combobox from 'discourse-common/components/combo-box';
import { CLOSE_STATUS_TYPE } from 'discourse/controllers/edit-topic-status-update';

const LATER_TODAY = 'later_today';
const TOMORROW = 'tomorrow';
const LATER_THIS_WEEK = 'later_this_week';
const THIS_WEEKEND = 'this_weekend';
const NEXT_WEEK = 'next_week';
export const PICK_DATE_AND_TIME = 'pick_date_and_time';
export const SET_BASED_ON_LAST_POST = 'set_based_on_last_post';

export const FORMAT = 'YYYY-MM-DD HH:mm';

export default Combobox.extend({
  classNames: ['auto-update-input-selector'],
  isCustom: Ember.computed.equal("value", PICK_DATE_AND_TIME),

  @computed()
  content() {
    const selections = [];
    const now = moment();
    const canScheduleToday = (24 - now.hour()) > 6;
    const day = now.day();

    if (canScheduleToday) {
      selections.push({
        id: LATER_TODAY,
        name: I18n.t('topic.auto_update_input.later_today')
      });
    }

    selections.push({
      id: TOMORROW,
      name: I18n.t('topic.auto_update_input.tomorrow')
    });

    if (!canScheduleToday && day < 4) {
      selections.push({
        id: LATER_THIS_WEEK,
        name: I18n.t('topic.auto_update_input.later_this_week')
      });
    }

    if (day < 5) {
      selections.push({
        id: THIS_WEEKEND,
        name: I18n.t('topic.auto_update_input.this_weekend')
      });
    }


    if (day !== 7)  {
      selections.push({
        id: NEXT_WEEK,
        name: I18n.t('topic.auto_update_input.next_week')
      });
    }

    selections.push({
      id: PICK_DATE_AND_TIME,
      name: I18n.t('topic.auto_update_input.pick_date_and_time')
    });

    if (this.get('statusType') === CLOSE_STATUS_TYPE) {
      selections.push({
        id: SET_BASED_ON_LAST_POST,
        name: I18n.t('topic.auto_update_input.set_based_on_last_post')
      });
    }

    return selections;
  },

  @observes('value')
  _updateInput() {
    if (this.get('isCustom')) return;
    let input = null;
    const { time } = this.get('updateAt');

    if (time && !Ember.isEmpty(this.get('value'))) {
      input = time.format(FORMAT);
    }

    this.set('input', input);
  },

  @computed('value')
  updateAt(value) {
    return this._updateAt(value);
  },

  comboTemplate(state) {
    return this._format(state);
  },

  selectionTemplate(state) {
    return this._format(state);
  },

  _format(state) {
    let { time, icon } = this._updateAt(state.id);
    let icons;

    if (icon) {
      icons = icon.split(',').map(i => {
        return `<i class='fa fa-${i}'/>`;
      }).join(" ");
    }

    if (time) {
      if (state.id === LATER_TODAY) {
        time = time.format('hh:mm a');
      } else {
        time = time.format('ddd, hh:mm a');
      }
    }

    let output = "";

    if (!Ember.isEmpty(icons)) {
      output += `<span class='auto-update-input-selector-icons'>${icons}</span>`;
    }

    output += `<span>${state.text}</span>`;

    if (time) {
      output += `<span class='auto-update-input-selector-datetime'>${time}</span>`;
    }

    return output;
  },

  _updateAt(selection) {
    let time = moment();
    let icon;
    const timeOfDay = this.get('statusType') !== CLOSE_STATUS_TYPE ? 8 : 18;

    switch(selection) {
      case LATER_TODAY:
        time = time.hour(18).minute(0);
        icon = 'desktop';
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
