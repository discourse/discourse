import { getPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: "apply-lazyYT",
  initialize() {
    const api = getPluginApi('0.1');
    api.decorateCooked($elem => $('.lazyYT', $elem).lazyYT());
  }
};
