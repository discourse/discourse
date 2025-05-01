const seenNames = new Set();

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
    window.define(name, [], () => module);
  }
}
