import { iconHTML } from 'discourse-common/lib/icon-library';
import DropdownButton from 'discourse/components/dropdown-button';
import computed from "ember-addons/ember-computed-decorators";

export default DropdownButton.extend({
  buttonExtraClasses: 'no-text',
  title: '',
  text: iconHTML('ellipsis-h'),
  classNames: ['group-member-dropdown'],

  @computed()
  dropDownContent() {
    const items = [
      {
        id: 'removeMember',
        title: I18n.t('groups.members.remove_member'),
        description: I18n.t('groups.members.remove_member_description'),
        icon: 'user-times'
      }
    ];

    return items;
  },

  clicked(id) {
    switch (id) {
      case 'removeMember':
        this.sendAction('removeMember', this.get('member'));
        break;
    }
  }
});
