const rawModules = import.meta.glob("./**/*.{gjs,js}", { eager: true });

const adminCompatModules = {};
for (let [key, mod] of Object.entries(rawModules)) {
  key = key.replace(/\.(gjs|js)$/, "");
  adminCompatModules[key] = mod;
}

export default adminCompatModules;
