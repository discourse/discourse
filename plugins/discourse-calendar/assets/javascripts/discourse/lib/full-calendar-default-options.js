import {
  getCalendarButtonsText,
  getCurrentBcp47Locale,
} from "./calendar-locale";

export default function fullCalendarDefaultOptions() {
  return {
    locale: getCurrentBcp47Locale(),
    buttonText: getCalendarButtonsText(),
  };
}
