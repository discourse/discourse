import {
  fourMonths,
  inNDays,
  LATER_TODAY_CUTOFF_HOUR,
  laterThisWeek,
  laterToday,
  MOMENT_FRIDAY,
  MOMENT_MONDAY,
  MOMENT_SATURDAY,
  MOMENT_SUNDAY,
  MOMENT_THURSDAY,
  nextBusinessWeekStart,
  nextMonth,
  now,
  oneHour,
  oneYear,
  sixMonths,
  thisWeekend,
  thousandYears,
  threeMonths,
  tomorrow,
  twoDays,
  twoHours,
  twoMonths,
  twoWeeks,
} from "discourse/lib/time-utils";
import { i18n } from "discourse-i18n";

export const TIME_SHORTCUT_TYPES = {
  ONE_HOUR: "one_hour",
  TWO_HOURS: "two_hours",
  LATER_TODAY: "later_today",
  TOMORROW: "tomorrow",
  THIS_WEEKEND: "this_weekend",
  NEXT_MONTH: "next_month",
  ONE_YEAR: "one_year",
  FOREVER: "forever",
  CUSTOM: "custom",
  RELATIVE: "relative",
  LAST_CUSTOM: "last_custom",
  NONE: "none",
  NOW: "now",
  START_OF_NEXT_BUSINESS_WEEK: "start_of_next_business_week",
  LATER_THIS_WEEK: "later_this_week",
  POST_LOCAL_DATE: "post_local_date",
};

export function defaultTimeShortcuts(timezone) {
  const shortcuts = timeShortcuts(timezone);
  return [
    shortcuts.laterToday(),
    shortcuts.tomorrow(),
    shortcuts.laterThisWeek(),
    shortcuts.thisWeekend(),
    shortcuts.monday(),
    shortcuts.nextMonth(),
  ];
}

export function extendedDefaultTimeShortcuts(timezone) {
  const shortcuts = timeShortcuts(timezone);
  return [
    shortcuts.laterToday(),
    shortcuts.tomorrow(),
    shortcuts.laterThisWeek(),
    shortcuts.monday(),
    shortcuts.twoWeeks(),
    shortcuts.nextMonth(),
    shortcuts.twoMonths(),
    shortcuts.threeMonths(),
    shortcuts.fourMonths(),
    shortcuts.sixMonths(),
    shortcuts.oneYear(),
    shortcuts.forever(),
  ];
}

export function specialShortcutOptions() {
  const shortcuts = timeShortcuts();
  return [shortcuts.lastCustom(), shortcuts.custom(), shortcuts.none()];
}

export function timeShortcuts(timezone) {
  return {
    oneHour() {
      return {
        id: TIME_SHORTCUT_TYPES.ONE_HOUR,
        icon: "angle-right",
        label: "time_shortcut.in_one_hour",
        time: oneHour(timezone),
        timeFormatKey: "dates.time",
      };
    },
    twoHours() {
      return {
        id: TIME_SHORTCUT_TYPES.TWO_HOURS,
        icon: "angle-right",
        label: "time_shortcut.in_two_hours",
        time: twoHours(timezone),
        timeFormatKey: "dates.time",
      };
    },
    laterToday() {
      return {
        id: TIME_SHORTCUT_TYPES.LATER_TODAY,
        icon: "angle-right",
        label: "time_shortcut.later_today",
        time: laterToday(timezone),
        timeFormatKey: "dates.time",
      };
    },
    tomorrow() {
      return {
        id: TIME_SHORTCUT_TYPES.TOMORROW,
        icon: "far-sun",
        label: "time_shortcut.tomorrow",
        time: tomorrow(timezone),
        timeFormatKey: "dates.time_short_day",
      };
    },
    twoDays() {
      return {
        id: "two_days",
        icon: "angle-right",
        label: "time_shortcut.two_days",
        time: twoDays(timezone),
        timeFormatKey: "dates.time_short_day",
      };
    },
    threeDays() {
      return {
        id: "three_days",
        icon: "angle-right",
        label: "time_shortcut.three_days",
        time: inNDays(timezone, 3),
        timeFormatKey: "dates.time_short_day",
      };
    },
    laterThisWeek() {
      return {
        id: TIME_SHORTCUT_TYPES.LATER_THIS_WEEK,
        icon: "angles-right",
        label: "time_shortcut.later_this_week",
        time: laterThisWeek(timezone),
        timeFormatKey: "dates.time_short_day",
      };
    },
    thisWeekend() {
      return {
        id: TIME_SHORTCUT_TYPES.THIS_WEEKEND,
        icon: "bed",
        label: "time_shortcut.this_weekend",
        time: thisWeekend(timezone),
        timeFormatKey: "dates.time_short_day",
      };
    },
    monday() {
      return {
        id: TIME_SHORTCUT_TYPES.START_OF_NEXT_BUSINESS_WEEK,
        icon: "briefcase",
        label:
          now(timezone).day() === MOMENT_MONDAY ||
          now(timezone).day() === MOMENT_SUNDAY
            ? "time_shortcut.start_of_next_business_week_alt"
            : "time_shortcut.start_of_next_business_week",
        time: nextBusinessWeekStart(timezone),
        timeFormatKey: "dates.long_no_year",
      };
    },
    nextMonth() {
      return {
        id: TIME_SHORTCUT_TYPES.NEXT_MONTH,
        icon: "far-calendar-plus",
        label: "time_shortcut.next_month",
        time: nextMonth(timezone),
        timeFormatKey: "dates.long_no_year",
      };
    },
    twoWeeks() {
      return {
        id: "two_weeks",
        icon: "far-clock",
        label: "time_shortcut.two_weeks",
        time: twoWeeks(timezone),
        timeFormatKey: "dates.long_no_year",
      };
    },
    twoMonths() {
      return {
        id: "two_months",
        icon: "far-calendar-plus",
        label: "time_shortcut.two_months",
        time: twoMonths(timezone),
        timeFormatKey: "dates.long_no_year",
      };
    },
    threeMonths() {
      return {
        icon: "far-calendar-plus",
        id: "three_months",
        label: "time_shortcut.three_months",
        time: threeMonths(timezone),
        timeFormatKey: "dates.long_no_year",
      };
    },
    fourMonths() {
      return {
        id: "four_months",
        icon: "far-calendar-plus",
        label: "time_shortcut.four_months",
        time: fourMonths(timezone),
        timeFormatKey: "dates.long_no_year",
      };
    },
    sixMonths() {
      return {
        id: "six_months",
        icon: "far-calendar-plus",
        label: "time_shortcut.six_months",
        time: sixMonths(timezone),
        timeFormatKey: "dates.long_with_year",
      };
    },
    oneYear() {
      return {
        id: TIME_SHORTCUT_TYPES.ONE_YEAR,
        icon: "far-calendar-plus",
        label: "time_shortcut.one_year",
        time: oneYear(timezone),
        timeFormatKey: "dates.long_with_year",
      };
    },
    forever() {
      return {
        id: TIME_SHORTCUT_TYPES.FOREVER,
        icon: "gavel",
        label: "time_shortcut.forever",
        time: thousandYears(timezone),
        timeFormatKey: "dates.long_with_year",
      };
    },
    custom() {
      return {
        icon: "calendar-days",
        id: TIME_SHORTCUT_TYPES.CUSTOM,
        label: "time_shortcut.custom",
        time: null,
        isCustomTimeShortcut: true,
      };
    },
    lastCustom() {
      return {
        icon: "arrow-rotate-left",
        id: TIME_SHORTCUT_TYPES.LAST_CUSTOM,
        label: "time_shortcut.last_custom",
        time: null,
        hidden: true,
      };
    },
    none() {
      return {
        icon: "ban",
        id: TIME_SHORTCUT_TYPES.NONE,
        label: "time_shortcut.none",
        time: null,
      };
    },
    now() {
      return {
        id: TIME_SHORTCUT_TYPES.NOW,
        icon: "wand-magic",
        label: "time_shortcut.now",
        time: now(timezone),
      };
    },
  };
}

export function hideDynamicTimeShortcuts(
  shortcuts,
  timezone,
  siteSettings = {}
) {
  const shortcutsToHide = new Set();
  const _now = now(timezone);
  if (_now.hour() >= LATER_TODAY_CUTOFF_HOUR) {
    shortcutsToHide.add(TIME_SHORTCUT_TYPES.LATER_TODAY);
  }

  if (_now.day === MOMENT_SUNDAY || _now.day() >= MOMENT_THURSDAY) {
    shortcutsToHide.add(TIME_SHORTCUT_TYPES.LATER_THIS_WEEK);
  }

  if (
    !siteSettings.suggest_weekends_in_date_pickers ||
    _now.day() === MOMENT_FRIDAY ||
    _now.day() === MOMENT_SATURDAY ||
    _now.day() === MOMENT_SUNDAY
  ) {
    shortcutsToHide.add(TIME_SHORTCUT_TYPES.THIS_WEEKEND);
  }

  return shortcuts.filter((s) => !shortcutsToHide.has(s.id));
}

export function formatTime(shortcut) {
  if (!shortcut.time || !shortcut.timeFormatKey) {
    return null;
  }

  return shortcut.time.format(i18n(shortcut.timeFormatKey));
}
