// A Mixin that a view can use to listen for 'url:refresh' when
// it is on screen, and will send an action to the controller to
// refresh its data.
//
// This is useful if you want to get around Ember's default
// behavior of not refreshing when navigating to the same place.

import { createViewListener } from 'discourse/lib/app-events';

export default createViewListener('url:refresh', function() {
  this.get('controller').send('refresh');
});
