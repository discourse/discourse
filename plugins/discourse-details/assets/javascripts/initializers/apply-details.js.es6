import { getPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: "apply-details",

  initialize() {
    const api = getPluginApi('0.1');
    api.decorateCooked($elem => $("details", $elem).details());
  }

};
