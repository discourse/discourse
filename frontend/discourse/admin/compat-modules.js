const seenNames = new Set();
const adminCompatModules = {};

const moduleSets = [
  import.meta.glob("./**/*.{gjs,js}", { eager: true }),
  import.meta.glob("./**/*.{hbs,hbr}", { eager: true }),
]
  .map((m) => Object.entries(m))
  .flat();

for (const [path, module] of moduleSets) {
  let name = path.replace("./", "admin/").replace(/\.\w+$/, "");
  if (!seenNames.has(name)) {
    seenNames.add(name);
    adminCompatModules[name] = module;
    window.define(name, [], () => module);
  }
}

export default adminCompatModules;
