const path = require("path");

module.exports = {
  mode: "production",
  output: {
    path: path.resolve(__dirname, "..", "..", "public", "javascripts"),
    filename: "text-unicode-dist.js",
    library: "otLib",
    libraryTarget: "umd",
    globalObject: "window",
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        use: { loader: "babel-loader" },
      },
    ],
  },
};
