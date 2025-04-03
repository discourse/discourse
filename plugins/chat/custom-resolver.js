import { globSync, readFileSync } from "node:fs";

const pluginName = JSON.parse(readFileSync("./package.json")).name;

const roots = [
  "discourse/app",
  "admin/addon",
  "select-kit/addon",
  "float-kit/addon",
  "dialog-holder/addon",
];

function itemExists(path) {
  return (
    globSync(`${path}.{js,gjs,hbs}`).length ||
    globSync(`${path}/index.{js,gjs,hbs}`).length
  );
}

export default async function (path) {
  if (!path.startsWith("@embroider/virtual/")) {
    return;
  }

  const name = path.replace("@embroider/virtual/", "").replace(".js", "");

  // core and bundled addons
  for (let location of roots) {
    const pkg = location.match(/(.+)\//)[1];
    if (itemExists(`../../app/assets/javascripts/${location}/${name}`)) {
      return `${pkg}/${name}`;
    }
  }

  // target plugin
  if (itemExists(`./assets/javascripts/discourse/${name}`)) {
    return `discourse/plugins/${pluginName}/discourse/${name}`;
  } else if (itemExists(`./admin/assets/javascripts/admin/${name}`)) {
    return `discourse/plugins/${pluginName}/admin/${name}`;
  }
}
