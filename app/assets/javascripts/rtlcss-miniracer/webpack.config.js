module.exports = {
  devtool: false,
  mode: "production",
  entry: "rtlcss",
  output: {
    iife: false,
    libraryTarget: "var",
    library: "rtlcss",
  },
};
