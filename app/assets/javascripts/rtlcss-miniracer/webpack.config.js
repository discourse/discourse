module.exports = {
  devtool: false,
  mode: "development",
  output: {
    iife: false,
    libraryTarget: "var",
    library: "rtlcss",
  },
  module: {
    rules: [
      {
        test: /\.css$/,
        exclude: /node_modules/,
        use: [
          {
            loader: "style-loader",
          },
          {
            loader: "css-loader",
            options: {
              importLoaders: 1,
            },
          },
          {
            loader: "postcss-loader",
          },
        ],
      },
    ],
  },
};
