let additionalReportModes = {};
export function registerReportModeComponent(mode, componentClass) {
  additionalReportModes[mode] = componentClass;
}
export function resetAdditionalReportModes() {
  additionalReportModes = {};
}
export function reportModeComponent(mode) {
  return additionalReportModes[mode];
}
