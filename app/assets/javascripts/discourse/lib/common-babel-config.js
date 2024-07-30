module.exports = function generateCommonBabelConfig() {
  return {
    "ember-cli-babel": {
      throwUnlessParallelizable: true,
      disableDecoratorTransforms: true,
    },

    babel: {
      sourceMaps: false,
      plugins: [
        require.resolve("deprecation-silencer"),
        [
          require.resolve("decorator-transforms"),
          {
            runEarly: true,
          },
        ],
        require.resolve("./babel-plugin-safari-class-fields-bugfix"),
      ],
    },
  };
};
