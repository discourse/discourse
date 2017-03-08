import { setting } from 'discourse/lib/computed';
import { buildCategoryPanel } from 'discourse/components/edit-category-panel';
import computed from "ember-addons/ember-computed-decorators";

export default buildCategoryPanel('settings', {
  emailInEnabled: setting('email_in'),
  showPositionInput: setting('fixed_category_positions'),

  isDefaultSortOrder: Em.computed.empty('category.sort_order'),

  @computed
  availableSorts() {
    return ['likes', 'op_likes', 'views', 'posts', 'activity', 'posters', 'category', 'created']
      .map(s => ({ name: I18n.t('category.sort_options.' + s), value: s }))
      .sort((a,b) => { return a.name > b.name; });
  },

  @computed
  sortAscendingOptions() {
    return [
      {name: I18n.t('category.sort_ascending'),  value: 'true'},
      {name: I18n.t('category.sort_descending'), value: 'false'}
    ];
  },

  @computed
  availableViews() {
    return [
      {name: I18n.t('filters.latest.title'), value: 'latest'},
      {name: I18n.t('filters.top.title'),    value: 'top'}
    ];
  }
});
