export default function () {
  const { disabled_plugins = [] } = this.site;

  if (disabled_plugins.indexOf("styleguide") !== -1) {
    return;
  }

  this.route("styleguide", function () {
    this.route("show", { path: ":category/:section" });
  });
}
