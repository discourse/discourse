"use strict";

const widgetHbsCompilerPath = require.resolve("./lib/widget-hbs-compiler");

module.exports = {
  name: require("./package").name,

  included() {
    this._super.included.apply(this, arguments);
    let addonOptions = this._getAddonOptions();
    addonOptions.babel = addonOptions.babel || {};
    addonOptions.babel.plugins = addonOptions.babel.plugins || [];
    let babelPlugins = addonOptions.babel.plugins;

    babelPlugins.push({
      _parallelBabel: {
        requireFile: widgetHbsCompilerPath,
        useMethod: "WidgetHbsCompiler",
      },
    });
  },

  _getAddonOptions() {
    return (
      (this.parent && this.parent.options) ||
      (this.app && this.app.options) ||
      {}
    );
  },
};
