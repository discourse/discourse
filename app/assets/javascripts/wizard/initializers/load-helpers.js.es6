export default {
  name: 'load-helpers',

  initialize() {
    Object.keys(requirejs.entries).forEach(entry => {
      if ((/\/helpers\//).test(entry)) {
        require(entry, null, null, true);
      }
    });
  }
};
