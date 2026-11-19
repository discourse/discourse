import SiteSetting, {
  isSettingValueTrue,
} from "discourse/admin/models/site-setting";
import { extractError } from "discourse/lib/ajax-error";

/**
 * Helpers for FormKit forms that edit site settings, one field per setting.
 */

/**
 * @param {SiteSetting[]} settings
 * @param {string} name
 */
export function findSetting(settings, name) {
  return settings.find((setting) => setting.setting === name);
}

/**
 * Applies `depends_behavior: hidden` using the form's unsaved values.
 *
 * @param {SiteSetting[]} settings
 * @param {SiteSetting} setting
 * @param {Object} data - the form data
 */
export function isSettingVisible(settings, setting, data) {
  if (!setting) {
    return false;
  }
  if (setting.depends_behavior !== "hidden") {
    return true;
  }

  return (setting.depends_on || []).every((name) => {
    const parent = findSetting(settings, name);
    if (!parent) {
      return true;
    }
    const value = Object.hasOwn(data, name) ? data[name] : parent.value;
    const allowedValues = setting.depends_on_values?.[name];
    return allowedValues
      ? allowedValues.map(String).includes(String(value))
      : isSettingValueTrue(value);
  });
}

/**
 * Saves the settings whose form value changed, in the order of `settings`, and
 * reports failures on their fields.
 *
 * A setting the form does not currently render must not be submitted: its draft
 * value may predate the change that hid it, and the server would reject it.
 *
 * @param {SiteSetting[]} settings
 * @param {Object} data - the form data
 * @param {Object} [formApi]
 * @param {(name: string, value: unknown) => void} [onSaved]
 * @param {Object} [options]
 * @param {(setting: SiteSetting) => boolean} [options.isVisible] - settings that
 *   fail this check are left untouched
 * @returns {Promise<boolean>} whether every changed setting was saved
 */
export async function saveSettings(
  settings,
  data,
  formApi,
  onSaved,
  { isVisible } = {}
) {
  formApi?.removeErrors();
  let success = true;

  for (const setting of settings) {
    const key = setting.setting;
    if (!Object.hasOwn(data, key) || (isVisible && !isVisible(setting))) {
      continue;
    }
    const value = data[key];
    if (isSameSettingValue(setting.value, value)) {
      continue;
    }

    try {
      await SiteSetting.update(key, value);
      setting.value = value;
      onSaved?.(key, value);
    } catch (error) {
      success = false;
      formApi?.addError(key, {
        title: setting.humanized_name,
        message: settingErrorMessage(key, error),
      });
    }
  }

  return success;
}

// Form values arrive as strings while saved values keep their type, so compare
// their string forms. A missing saved value only matches a missing form value.
function isSameSettingValue(savedValue, formValue) {
  return (
    savedValue === formValue ||
    (savedValue != null &&
      formValue != null &&
      savedValue.toString() === formValue.toString())
  );
}

// The field already names the setting, so drop the "setting_name: " prefix the server adds.
function settingErrorMessage(name, error) {
  const message = error.jqXHR?.responseJSON?.errors?.[0];
  return message ? message.replace(`${name}: `, "") : extractError(error);
}
