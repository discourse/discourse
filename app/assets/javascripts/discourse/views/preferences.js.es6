import { createViewWithBodyClass } from 'discourse/lib/create-view';

export default createViewWithBodyClass('user-preferences-page').extend({
  templateName: 'user/preferences',
  classNames: ['user-preferences']
});
