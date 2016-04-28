export function autoLoadModules() {
  Object.keys(requirejs.entries).forEach(entry => {
    if ((/\/helpers\//).test(entry)) {
      require(entry, null, null, true);
    }
    if ((/\/widgets\//).test(entry)) {
      require(entry, null, null, true);
    }
  });
}

export default {
  name: 'auto-load-modules',
  initialize: autoLoadModules
};
