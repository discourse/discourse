/**
 * How the setting that enables an AI module or feature can be controlled.
 *
 * @param {{ value: boolean, can_enable: boolean }} [setting]
 * @returns {"toggle" | "setup" | null} `setup` when enabling is blocked by
 *   missing configuration, `null` when no single setting controls it
 */
export function enabledSettingControl(setting) {
  if (!setting) {
    return null;
  }
  return setting.value || setting.can_enable ? "toggle" : "setup";
}
