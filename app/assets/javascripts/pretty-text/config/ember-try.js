"use strict";

const getChannelURL = require("ember-source-channel-url");

module.exports = async function() {
  return {
    useYarn: true,
    scenarios: [
      {
        name: "ember-lts-3.8",
        npm: {
          devDependencies: {
            "ember-source": "~3.8.0"
          }
        }
      },
      {
        name: "ember-lts-3.12",
        npm: {
          devDependencies: {
            "ember-source": "~3.12.0"
          }
        }
      },
      {
        name: "ember-release",
        npm: {
          devDependencies: {
            "ember-source": await getChannelURL("release")
          }
        }
      },
      {
        name: "ember-beta",
        npm: {
          devDependencies: {
            "ember-source": await getChannelURL("beta")
          }
        }
      },
      {
        name: "ember-canary",
        npm: {
          devDependencies: {
            "ember-source": await getChannelURL("canary")
          }
        }
      },
      // The default `.travis.yml` runs this scenario via `yarn test`,
      // not via `ember try`. It's still included here so that running
      // `ember try:each` manually or from a customized CI config will run it
      // along with all the other scenarios.
      {
        name: "ember-default",
        npm: {
          devDependencies: {}
        }
      },
      {
        name: "ember-default-with-jquery",
        env: {
          EMBER_OPTIONAL_FEATURES: JSON.stringify({
            "jquery-integration": true
          })
        },
        npm: {
          devDependencies: {
            "@ember/jquery": "^0.5.1"
          }
        }
      },
      {
        name: "ember-classic",
        env: {
          EMBER_OPTIONAL_FEATURES: JSON.stringify({
            "application-template-wrapper": true,
            "default-async-observers": false,
            "template-only-glimmer-components": false
          })
        },
        npm: {
          ember: {
            edition: "classic"
          }
        }
      }
    ]
  };
};
