import {
  MOMENT_MONDAY,
  MOMENT_SUNDAY,
  laterThisWeek,
  laterToday,
  nextBusinessWeekStart,
  nextMonth,
  now,
  sixMonths,
  thisWeekend,
  tomorrow,
  twoWeeks,
} from "discourse/lib/time-utils";

export const TIME_SHORTCUT_TYPES = {
  LATER_TODAY: "later_today",
  TOMORROW: "tomorrow",
  THIS_WEEKEND: "this_weekend",
  NEXT_MONTH: "next_month",
  CUSTOM: "custom",
  RELATIVE: "relative",
  LAST_CUSTOM: "last_custom",
  NONE: "none",
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

export function specialShortcutOptions() {
  return [
    {
      icon: "undo",
      id: TIME_SHORTCUT_TYPES.LAST_CUSTOM,
      label: "time_shortcut.last_custom",
      time: null,
      hidden: true,
    },
    {
      icon: "calendar-alt",
      id: TIME_SHORTCUT_TYPES.CUSTOM,
      label: "time_shortcut.custom",
      time: null,
      isCustomTimeShortcut: true,
    },
    {
      icon: "ban",
      id: TIME_SHORTCUT_TYPES.NONE,
      label: "time_shortcut.none",
      time: null,
    },
  ];
}

export function timeShortcuts(timezone) {
  return {
    laterToday() {
      return {
        icon: "angle-right",
        id: TIME_SHORTCUT_TYPES.LATER_TODAY,
        label: "time_shortcut.later_today",
        time: laterToday(timezone),
        timeFormatKey: "dates.time",
      };
    },
    tomorrow() {
      return {
        icon: "far-sun",
        id: TIME_SHORTCUT_TYPES.TOMORROW,
        label: "time_shortcut.tomorrow",
        time: tomorrow(timezone),
        timeFormatKey: "dates.time_short_day",
      };
    },
    laterThisWeek() {
      return {
        icon: "angle-double-right",
        id: TIME_SHORTCUT_TYPES.LATER_THIS_WEEK,
        label: "time_shortcut.later_this_week",
        time: laterThisWeek(timezone),
        timeFormatKey: "dates.time_short_day",
      };
    },
    thisWeekend() {
      return {
        icon: "bed",
        id: TIME_SHORTCUT_TYPES.THIS_WEEKEND,
        label: "time_shortcut.this_weekend",
        time: thisWeekend(timezone),
        timeFormatKey: "dates.time_short_day",
      };
    },
    monday() {
      return {
        icon: "briefcase",
        id: TIME_SHORTCUT_TYPES.START_OF_NEXT_BUSINESS_WEEK,
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
        icon: "far-calendar-plus",
        id: TIME_SHORTCUT_TYPES.NEXT_MONTH,
        label: "time_shortcut.next_month",
        time: nextMonth(timezone),
        timeFormatKey: "dates.long_no_year",
      };
    },
    twoWeeks() {
      return {
        icon: "far-clock",
        id: "two_weeks",
        label: "time_shortcut.two_weeks",
        time: twoWeeks(timezone),
        timeFormatKey: "dates.long_no_year",
      };
    },
    sixMonths() {
      return {
        icon: "far-calendar-plus",
        id: "six_months",
        label: "time_shortcut.six_months",
        time: sixMonths(timezone),
        timeFormatKey: "dates.long_no_year",
      };
    },
  };
}
