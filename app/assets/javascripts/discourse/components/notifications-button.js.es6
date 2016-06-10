import DropdownButton from 'discourse/components/dropdown-button';
import { all, buttonDetails } from 'discourse/lib/notification-levels';
import { iconHTML } from 'discourse/helpers/fa-icon';
import computed from 'ember-addons/ember-computed-decorators';

export default DropdownButton.extend({
  classNames: ['notification-options'],
  title: '',
  buttonIncludesText: true,
  activeItem: Em.computed.alias('notificationLevel'),
  i18nPrefix: '',
  i18nPostfix: '',

  @computed
  dropDownContent() {
    const prefix = this.get('i18nPrefix');
    const postfix = this.get('i18nPostfix');

    return all.map(l => {
      const start = `${prefix}.${l.key}${postfix}`;
      return {
        id: l.id,
        title: I18n.t(`${start}.title`),
        description: I18n.t(`${start}.description`),
        styleClasses: `${l.key} fa fa-${l.icon}`
      };
    });
  },

  @computed('notificationLevel')
  text(notificationLevel) {
    const details = buttonDetails(notificationLevel);
    const { key } = details;
    const icon = iconHTML(details.icon, { class: key });

    if (this.get('buttonIncludesText')) {
      const prefix = this.get('i18nPrefix');
      const postfix = this.get('i18nPostfix');
      const text = I18n.t(`${prefix}.${key}${postfix}.title`);
      return `${icon}&nbsp;${text}<span class='caret'></span>`;
    } else {
      return `${icon}&nbsp;<span class='caret'></span>`;
    }
  },

  clicked(/* id */) {
    // sub-class needs to implement this
  }
});
