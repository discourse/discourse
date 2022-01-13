document.write(
  "<style>#ember-testing-container { position: fixed; background: white; bottom: 0; right: 0; width: 640px; height: 384px; overflow: auto; z-index: 9999; border: 1px solid #ccc; transform: translateZ(0)} #ember-testing { width: 200%; height: 200%; transform: scale(0.5); transform-origin: top left; }</style>"
);
require('discourse/tests/test-boot-ember-cli');
