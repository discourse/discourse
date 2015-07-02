import { buildCategoryPanel } from 'discourse/components/edit-category-panel';

export default buildCategoryPanel('settings', {
  emailInEnabled: Discourse.computed.setting('email_in'),
  showPositionInput: Discourse.computed.setting('fixed_category_positions'),
});
