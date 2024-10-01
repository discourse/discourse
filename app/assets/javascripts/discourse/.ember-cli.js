const defaultConfig = {
  isTypeScriptProject: false,
};

if (process.env.CODESPACE_NAME) {
  defaultConfig.liveReloadJsUrl = `/_lr/livereload.js`;
  defaultConfig.liveReloadOptions = {
    port: 443,
    https: true,
    host: `${process.env.CODESPACE_NAME}-4200.${process.env.GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}`,
    path: "_lr/livereload",
  };
}

module.exports = defaultConfig;
