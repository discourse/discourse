export const pluginActivitiesFuncs = [];

export function addAboutPageActivity(name, func) {
  pluginActivitiesFuncs.push({ name, func });
}

export function clearAboutPageActivities() {
  pluginActivitiesFuncs.length = 0;
}
