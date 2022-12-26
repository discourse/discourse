# rtlcss-miniracer

This package manages our MiniRacer-consumable copy of the [`rtlcss` library](https://www.npmjs.com/package/rtlcss). The `dist/main.js` file in this package is what MiniRacer consumes and it contains the `rtlcss` library and all of its dependencies.

To upgrade the `rtlcss` version that we use in MiniRacer:

1. Bump the version number of `rtlcss` in the `package.json` file in this directory to the desired version

2. Run `yarn install` in this directory followed by `yarn webpack`

The last command rebuilds the `dist/main.js` file with the version of `rtlcss` that's specified in the `package.json` file. You need to then include the changes you've made to `package.json` as well as any changes that have been by the commands in your PR.
