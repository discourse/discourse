import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { iconNode  } from 'discourse/helpers/fa-icon';

function description(attrs) {
  const daysSince = attrs.daysSince;

  if (daysSince < 30) {
    return I18n.t('dates.later.x_days', {count: daysSince});
  } else if (daysSince < 365) {
    const gapMonths = Math.floor(daysSince / 30);
    return I18n.t('dates.later.x_months', {count: gapMonths});
  } else {
    const gapYears = Math.floor(daysSince / 365);
    return I18n.t('dates.later.x_years', {count: gapYears});
  }
}

export default createWidget('time-gap', {
  tagName: 'div.time-gap.small-action.clearfix',

  html(attrs) {
    return [h('div.topic-avatar', iconNode('fw')),
            h('div.small-action-desc.timegap', description(attrs))];
  }
});
