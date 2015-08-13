import { setting } from 'discourse/lib/computed';
import { buildCategoryPanel } from 'discourse/components/edit-category-panel';

export default buildCategoryPanel('settings', {
  emailInEnabled: setting('email_in'),
  showPositionInput: setting('fixed_category_positions'),
});
