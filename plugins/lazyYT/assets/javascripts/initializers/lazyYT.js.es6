import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: "apply-lazyYT",
  initialize() {
    withPluginApi('0.1', api => {
      api.decorateCooked($elem => $('.lazyYT', $elem).lazyYT());
    });
  }
};
