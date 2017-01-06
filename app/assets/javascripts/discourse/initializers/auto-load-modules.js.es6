import { registerHelpers } from 'discourse-common/lib/helpers';

export function autoLoadModules(container, registry) {
  Object.keys(requirejs.entries).forEach(entry => {
    if ((/\/helpers\//).test(entry)) {
      require(entry, null, null, true);
    }
    if ((/\/widgets\//).test(entry)) {
      require(entry, null, null, true);
    }
  });
  registerHelpers(registry);
}

export default {
  name: 'auto-load-modules',
  initialize: autoLoadModules
};
