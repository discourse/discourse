const rawModules = import.meta.glob("./**/*.{gjs,js,ts,gts}", { eager: true });

const adminCompatModules = {};
for (let [key, mod] of Object.entries(rawModules)) {
  key = key.replace(/\.(gjs|js|ts|gts)$/, "");
  adminCompatModules[key] = mod;
}

export default adminCompatModules;
