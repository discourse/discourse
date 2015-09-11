import { iconHTML } from 'discourse/helpers/fa-icon';
import DropdownButton from 'discourse/components/dropdown-button';
import computed from "ember-addons/ember-computed-decorators";

export default DropdownButton.extend({
  buttonExtraClasses: 'no-text',
  title: '',
  text: iconHTML('bars') + ' ' + iconHTML('caret-down'),
  classNames: ['category-notification-menu', 'category-admin-menu'],

  @computed()
  dropDownContent() {
    const includeReorder = this.get('siteSettings.fixed_category_positions');
    const items = [
      { id: 'create',
        title: I18n.t('category.create'),
        description: I18n.t('category.create_long'),
        styleClasses: 'fa fa-plus' }
    ];
    if (includeReorder) {
      items.push({
        id: 'reorder',
        title: I18n.t('categories.reorder.title'),
        description: I18n.t('categories.reorder.title_long'),
        styleClasses: 'fa fa-random'
      });
    }
    return items;
  },

  actionNames: {
    create: 'createCategory',
    reorder: 'reorderCategories'
  },

  clicked(id) {
    this.sendAction('actionNames.' + id);
  }
});
