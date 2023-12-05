# checklist

This is an existing legacy plugin converted into v2. It also contains backend
code, so this also showcases how the frontend and backend code can coexist in
harmony.

## No-build

This plugin does not use any features that requires a build step, and so it is
set up to not have a build pipeline. The plugin features are maintained by hand
in `package.json`.

The frontend files are located in `assets/javascripts` to show that there is no
particular requirement for the layout, as long as the module paths are standard
in the `exports` map in `package.json`.

It would be pretty straightforward to introduce the rollup build to this plugin
if it becomes necessary, e.g. to add `.gjs` support. It can be done without
relocating the files also, as the `Plugin` constructor allows specifying the
location of the `srcDir` and `destDir`.
