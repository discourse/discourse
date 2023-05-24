// TODO - ember-try doesn't seem to work with the 'xss' package in node_modules.
// Looks like a symlink in the package causes issues with the node_modules copying.
module.exports = function () {
  return {
    command: 'echo "specify a command to run" && exit 1',
    useYarn: true,
    scenarios: [
      {
        name: "Ember 4.4",
        env: {},
        npm: {
          dependencies: {
            "ember-source": "~4.4.0",
            "ember-cached-decorator-polyfill": null, // no longer required
          },
          ember: {
            edition: "octane",
          },
        },
      },
    ],
  };
};
