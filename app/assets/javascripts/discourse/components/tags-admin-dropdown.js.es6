import { iconHTML } from 'discourse-common/helpers/fa-icon';
import DropdownButton from 'discourse/components/dropdown-button';
import computed from "ember-addons/ember-computed-decorators";

export default DropdownButton.extend({
  buttonExtraClasses: 'no-text',
  title: '',
  text: iconHTML('bars') + ' ' + iconHTML('caret-down'),
  classNames: ['tags-admin-menu'],

  @computed()
  dropDownContent() {
    const items = [
      { id: 'manageGroups',
        title: I18n.t('tagging.manage_groups'),
        description: I18n.t('tagging.manage_groups_description'),
        styleClasses: 'fa fa-wrench' }
    ];
    return items;
  },

  actionNames: {
    manageGroups: 'showTagGroups'
  },

  clicked(id) {
    this.sendAction('actionNames.' + id);
  }
});
