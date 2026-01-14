let additionalReportModes = new Map();
export function registerReportModeComponent(mode, componentClass) {
  additionalReportModes.set(mode, componentClass);
}
export function resetAdditionalReportModes() {
  additionalReportModes.clear();
}
export function reportModeComponent(mode) {
  return additionalReportModes.get(mode);
}
