const crypto = require("crypto");
const mergeTrees = require("broccoli-merge-trees");
const funnel = require("broccoli-funnel");

module.exports = function generateWorkboxTree() {
  const workboxDeps = [
    "workbox-sw",
    "workbox-routing",
    "workbox-core",
    "workbox-strategies",
    "workbox-expiration",
    "workbox-cacheable-response",
  ];

  const nodes = workboxDeps.map((name) => {
    return funnel(`../node_modules/${name}/build`);
  });

  const versions = workboxDeps.map((name) => {
    return require(`../../node_modules/${name}/package.json`).version;
  });

  // Normally Sprockets will create a cachebuster per-file. In this case we need it at the directory level since
  // workbox is responsible for loading its own files and doesn't support customized names per-file.
  // Sprockets' default behaviour for these files is disabled via freedom_patches/sprockets.rb.
  const versionHash = crypto
    .createHash("md5")
    .update(versions.join("|"))
    .digest("hex");

  return funnel(mergeTrees(nodes), {
    destDir: `assets/workbox-${versionHash}`,
  });
};
