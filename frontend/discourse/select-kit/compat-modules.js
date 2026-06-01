const rawModules = import.meta.glob("./**/*.{gjs,js}", { eager: true });

const compatModules = {};
for (let [key, mod] of Object.entries(rawModules)) {
  key = key.replace(/\.(gjs|js)$/, "");
  compatModules[key] = mod;
}

export default compatModules;
