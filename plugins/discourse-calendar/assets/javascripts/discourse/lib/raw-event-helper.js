import { buildBBCodeAttrs, parseBBCodeTag } from "discourse/lib/text";

// `([\w-]+\.)*` allows any subdomain, since livestream hosts routinely use them
// (us06web.zoom.us, www.youtube.com). It cannot match a host that merely ends in
// one of these names, because each captured label must be followed by a dot:
// "notzoom.us" and "zoom.us.evil.com" are both rejected.
const LIVESTREAM_URL =
  /^(https?:\/\/)?([\w-]+\.)*(youtube\.com|youtu\.be|twitch\.tv|zoom\.us|kick\.com|tiktok\.com|instagram\.com|facebook\.com)\//i;

export function isLivestreamUrl(url) {
  return LIVESTREAM_URL.test(url ?? "");
}

export function defaultReminderFor({ startsAt, endsAt, allDay } = {}) {
  const start = startsAt ? moment(startsAt) : null;
  const end = endsAt ? moment(endsAt) : null;
  const isMultiDay = !!(start && end && !start.isSame(end, "day"));

  if (allDay || isMultiDay) {
    return { type: "notification", value: 1, unit: "days", period: "before" };
  }

  return { type: "notification", value: 15, unit: "minutes", period: "before" };
}

export function reminderToBBCode(reminder) {
  const raw = parseInt(reminder.value, 10);
  const magnitude = Math.abs(Number.isFinite(raw) ? raw : 0);
  const value = reminder.period === "after" ? -magnitude : magnitude;
  return `${reminder.type}.${value}.${reminder.unit}`;
}

function matchesDefault(reminder, def) {
  return (
    reminder &&
    reminder.value === def.value &&
    reminder.unit === def.unit &&
    reminder.period === def.period
  );
}

// compute the next state when transitioning between attendance modes
export function attendanceTransition({
  mode,
  status,
  maxAttendees,
  reminders,
  previousRsvpStatus,
  previousMaxAttendees,
}) {
  let nextStatus = status;
  let nextMax = maxAttendees;
  let nextReminders = reminders || [];
  let nextPrevRsvp = previousRsvpStatus;
  let nextPrevMax = previousMaxAttendees;

  if (mode === "none") {
    if (status && status !== "standalone") {
      nextPrevRsvp = status;
    }
    if (maxAttendees) {
      nextPrevMax = maxAttendees;
    }
    nextStatus = "standalone";
    nextMax = null;
    nextReminders = nextReminders.map((r) =>
      r.type === "notification" ? { ...r, type: "bumpTopic" } : r
    );
  } else {
    if (status === "standalone") {
      nextStatus = previousRsvpStatus || "public";
      nextReminders = nextReminders.map((r) =>
        r.type === "bumpTopic" ? { ...r, type: "notification" } : r
      );
    }
    if (mode === "unlimited") {
      if (maxAttendees) {
        nextPrevMax = maxAttendees;
      }
      nextMax = null;
    } else if (mode === "upTo") {
      nextMax = previousMaxAttendees || null;
    }
  }

  return {
    status: nextStatus,
    maxAttendees: nextMax,
    reminders: nextReminders,
    previousRsvpStatus: nextPrevRsvp,
    previousMaxAttendees: nextPrevMax,
  };
}

// if the default is unchanged, swap it out based on the new config
export function reconcileDefaultReminder(reminders, oldConfig, newConfig) {
  if (!reminders || reminders.length !== 1) {
    return reminders;
  }
  const oldDefault = defaultReminderFor(oldConfig);
  const newDefault = defaultReminderFor(newConfig);
  if (matchesDefault(oldDefault, newDefault)) {
    return reminders;
  }
  if (!matchesDefault(reminders[0], oldDefault)) {
    return reminders;
  }
  return [
    {
      ...reminders[0],
      value: newDefault.value,
      unit: newDefault.unit,
      period: newDefault.period,
    },
  ];
}

export function buildParams(startsAt, endsAt, event, siteSettings) {
  const params = {};

  const eventTz = event.timezone || "UTC";

  params.start = event.allDay
    ? moment(startsAt).format("YYYY-MM-DD")
    : moment(startsAt).tz(eventTz).format("YYYY-MM-DD HH:mm");

  if (event.isClosed) {
    params.closed = "true";
  }

  if (event.status) {
    params.status = event.status;
  }

  if (event.name && event.name.trim()) {
    params.name = event.name;
  }

  if (event.location && event.location.trim()) {
    params.location = event.location;
  }

  if (event.description && event.description.trim()) {
    params.description = event.description;
  }

  if (event.url && event.url.trim()) {
    params.url = event.url;
  }

  if (event.timezone) {
    params.timezone = event.timezone;
  }

  if (event.recurrence) {
    params.recurrence = event.recurrence;
  }

  if (event.recurrenceUntil) {
    params.recurrenceUntil = moment(event.recurrenceUntil)
      .tz(eventTz)
      .format("YYYY-MM-DD HH:mm");
  }

  if (event.showLocalTime) {
    params.showLocalTime = "true";
  }

  if (event.minimal) {
    params.minimal = "true";
  }

  if (event.chatEnabled) {
    params.chatEnabled = "true";
  }

  if (event.livestream) {
    params.livestream = "true";
  }

  if (event.maxAttendees) {
    params.maxAttendees = `${event.maxAttendees}`;
  }

  if (event.allDay) {
    params.allDay = "true";
  }

  if (endsAt) {
    params.end = event.allDay
      ? moment(endsAt).format("YYYY-MM-DD")
      : moment(endsAt).tz(eventTz).format("YYYY-MM-DD HH:mm");
  }

  if (event.status === "private") {
    params.allowedGroups = (event.rawInvitees || []).join(",");
  }

  if (event.reminders && event.reminders.length) {
    params.reminders = event.reminders
      .map((r) => {
        // we create a new intermediate object to avoid changes in the UI while
        // we prepare the values for request
        const reminder = Object.assign({}, r);

        if (reminder.period === "after") {
          reminder.value = `-${Math.abs(parseInt(reminder.value, 10))}`;
        }
        if (reminder.period === "before") {
          reminder.value = Math.abs(parseInt(`${reminder.value}`, 10));
        }

        return `${reminder.type}.${reminder.value}.${reminder.unit}`;
      })
      .join(",");
  }

  if (event.imageUpload?.short_url) {
    params.image = event.imageUpload.short_url;
  } else if (event.imageUpload?.url) {
    params.image = event.imageUpload.url;
  }

  siteSettings.discourse_post_event_allowed_custom_fields
    .split("|")
    .filter(Boolean)
    .forEach((setting) => {
      const param = camelCase(setting);
      if (typeof event.customFields[setting] !== "undefined") {
        params[param] = event.customFields[setting];
      }
    });

  return params;
}

const EVENT_CLOSE_TAG = "[/event]";

function dashedToCamel(key) {
  return key.replace(/-([a-zA-Z0-9])/g, (_, c) => c.toUpperCase());
}

export function parseEventBlock(raw) {
  if (!raw) {
    return null;
  }

  let start = raw.indexOf("[event");
  while (start !== -1) {
    const parsed = parseBBCodeTag(raw, start, raw.length);

    if (parsed?.tag === "event" && !parsed.closing) {
      const bodyStart = start + parsed.length;
      const close = raw.indexOf(EVENT_CLOSE_TAG, bodyStart);
      if (close === -1) {
        return null;
      }

      const attrs = {};
      for (const [key, value] of Object.entries(parsed.attrs || {})) {
        if (key !== "_default") {
          attrs[dashedToCamel(key)] = value;
        }
      }

      const description = raw
        .slice(bodyStart, close)
        .replace(/^\n/, "")
        .replace(/\n$/, "");

      return {
        full: raw.slice(start, close + EVENT_CLOSE_TAG.length),
        attrs,
        description,
      };
    }

    start = raw.indexOf("[event", start + 1);
  }

  return null;
}

export function buildEventBlock(params, description) {
  const attrs = Object.fromEntries(
    Object.entries(params).filter(
      ([key, value]) =>
        key !== "description" && value != null && String(value).trim() !== ""
    )
  );
  const desc = description ? `${description}\n` : "";
  return `[event ${buildBBCodeAttrs(attrs)}]\n${desc}[/event]`;
}

export function getCustomFieldNames(siteSettings) {
  return siteSettings.discourse_post_event_allowed_custom_fields
    .split("|")
    .filter(Boolean);
}

export function customFieldFormName(name) {
  return name.replace(/[.-]/g, "_");
}

// anywhere that builds an event state should use this as the single source of truth for defaults
export function defaultEventState() {
  return {
    name: null,
    location: null,
    description: "",
    timezone: "UTC",
    status: "public",
    maxAttendees: null,
    allDay: false,
    startsAt: null,
    endsAt: null,
    reminders: [],
    recurrence: null,
    recurrenceUntil: null,
    showLocalTime: false,
    chatEnabled: false,
    livestream: false,
    minimal: false,
    url: null,
    image: null,
    allowedGroups: null,
    closed: false,
    customFields: {},
  };
}

export function parseEventAttrs(
  attrs,
  { fallbackTimezone, customFieldNames } = {}
) {
  const tz = attrs.timezone || fallbackTimezone || "UTC";
  const customFields = {};
  (customFieldNames || []).forEach((field) => {
    const param = camelCase(field);
    if (typeof attrs[param] !== "undefined") {
      customFields[field] = attrs[param];
    }
  });

  return {
    ...defaultEventState(),
    name: attrs.name || null,
    location: attrs.location || null,
    timezone: tz,
    status: attrs.status || "public",
    maxAttendees: attrs.maxAttendees ? parseInt(attrs.maxAttendees, 10) : null,
    allDay: attrs.allDay === "true",
    startsAt: attrs.start ? moment.tz(attrs.start, tz) : null,
    endsAt: attrs.end ? moment.tz(attrs.end, tz) : null,
    reminders: parseReminders(attrs.reminders),
    recurrence: attrs.recurrence || null,
    recurrenceUntil: attrs.recurrenceUntil || null,
    showLocalTime: attrs.showLocalTime === "true",
    chatEnabled: attrs.chatEnabled === "true",
    livestream: attrs.livestream === "true",
    minimal: attrs.minimal === "true",
    url: attrs.url || null,
    image: attrs.image || null,
    allowedGroups: attrs.allowedGroups || null,
    closed: attrs.closed === "true",
    customFields,
  };
}

export function stateToEventInput(state) {
  return {
    timezone: state.timezone,
    allDay: state.allDay,
    isClosed: state.closed,
    status: state.status,
    name: state.name,
    location: state.location,
    url: state.url,
    recurrence: state.recurrence,
    recurrenceUntil: state.recurrenceUntil,
    showLocalTime: state.showLocalTime,
    minimal: state.minimal,
    chatEnabled: state.chatEnabled,
    livestream: state.livestream,
    maxAttendees: state.maxAttendees,
    rawInvitees: state.allowedGroups ? state.allowedGroups.split(",") : [],
    reminders: state.reminders,
    imageUpload: state.image ? { url: state.image } : null,
    customFields: state.customFields,
  };
}

export function parseReminders(reminders) {
  if (!reminders) {
    return [];
  }
  if (Array.isArray(reminders)) {
    return reminders;
  }
  return reminders.split(",").map((reminderStr) => {
    const [type, value, unit] = reminderStr.split(".");
    const numericValue = Math.abs(parseInt(value, 10));
    return {
      type: type || "notification",
      value: numericValue,
      unit: unit || "hours",
      period: parseInt(value, 10) < 0 ? "after" : "before",
    };
  });
}

export function replaceRaw(params, raw) {
  const parsed = parseEventBlock(raw);
  if (!parsed) {
    return false;
  }
  return raw.replace(parsed.full, () =>
    buildEventBlock(params, params.description)
  );
}

export function camelCase(input) {
  return input
    .toLowerCase()
    .replace(/[-.]/g, "_")
    .replace(/_(.)/g, function (match, group1) {
      return group1.toUpperCase();
    });
}

export function removeEvent(raw) {
  const parsed = parseEventBlock(raw);
  return parsed ? raw.replace(parsed.full, "") : raw;
}

export function buildEventSkeleton(currentUser) {
  const timezone = currentUser?.user_option?.timezone || moment.tz.guess();
  const startsAt = moment.tz(moment(), timezone).startOf("hour").add(1, "hour");
  const endsAt = startsAt.clone().add(1, "hour");
  const reminder = defaultReminderFor({ startsAt, endsAt, allDay: false });
  const defaults = `start="${startsAt.format("YYYY-MM-DD HH:mm")}" end="${endsAt.format("YYYY-MM-DD HH:mm")}" status="public" timezone="${timezone}" reminders="${reminderToBBCode(reminder)}"`;
  return `[event ${defaults}]\n[/event]`;
}
