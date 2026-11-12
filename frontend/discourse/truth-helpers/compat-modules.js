const rawModules = import.meta.glob("./**/*.{gjs,js,ts,gts}", { eager: true });

const compatModules = {};
for (let [key, mod] of Object.entries(rawModules)) {
  key = key.replace(/\.(gjs|js|ts|gts)$/, "");
  compatModules[key] = mod;
}

export default compatModules;
