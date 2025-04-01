import fs from "node:fs";

const pluginName = "chat";

const roots = [
  "discourse/app",
  "admin/addon",
  "select-kit/addon",
  "float-kit/addon",
  "dialog-holder/addon",
];

function itemExists(path) {
  return (
    fs.globSync(`${path}.{js,gjs,hbs}`).length ||
    fs.globSync(`${path}/index.{js,gjs,hbs}`).length
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

  // styleguide
  if (itemExists(`../styleguide/assets/javascripts/discourse/${name}`)) {
    return `discourse/plugins/styleguide/discourse/${name}`;
  }

  // d-lazy-videos
  if (
    itemExists(`../discourse-lazy-videos/assets/javascripts/discourse/${name}`)
  ) {
    return `discourse/plugins/discourse-lazy-videos/discourse/${name}`;
  }
}
