// must be an https link to livestream
export function isLivestreamUrl(location) {
  return /^https?:\/\//i.test(location ?? "");
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

const EVENT_BBCODE_REGEX = /\[event (.*?)\](.*?)\[\/event\]/s;
const EVENT_BLOCK_REGEX = /\[event\b([^\]]*)\](.*?)\[\/event\]/s;
const ATTR_REGEX = /([-\w]+)=(?:"([^"]*)"|'([^']*)'|([^\s\]]+))/g;

function dashedToCamel(key) {
  return key.replace(/-([a-zA-Z0-9])/g, (_, c) => c.toUpperCase());
}

export function parseEventBlock(raw) {
  if (!raw) {
    return null;
  }
  const match = raw.match(EVENT_BLOCK_REGEX);
  if (!match) {
    return null;
  }
  const attrs = {};
  for (const m of match[1].matchAll(ATTR_REGEX)) {
    const [, key, dq, sq, unq] = m;
    const value = dq ?? sq ?? unq ?? "";
    attrs[dashedToCamel(key)] = value;
  }
  const description = (match[2] || "").replace(/^\n/, "").replace(/\n$/, "");
  return { full: match[0], attrs, description };
}

export function buildEventBlock(params, description) {
  const parts = Object.entries(params)
    .filter(([, v]) => v != null && v !== "" && String(v).trim() !== "")
    .map(([k, v]) => `${k}="${String(v).replace(/"/g, "")}"`);
  const desc = description ? `${description}\n` : "";
  return `[event ${parts.join(" ")}]\n${desc}[/event]`;
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
  if (!EVENT_BBCODE_REGEX.test(raw)) {
    return false;
  }
  const { description, ...attrs } = params;
  return raw.replace(EVENT_BBCODE_REGEX, buildEventBlock(attrs, description));
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
  return raw.replace(/\[event (.*?)\](.*?)\[\/event\]/s, "");
}

export function buildEventSkeleton(currentUser) {
  const timezone = currentUser?.user_option?.timezone || moment.tz.guess();
  const startsAt = moment.tz(moment(), timezone).startOf("hour").add(1, "hour");
  const endsAt = startsAt.clone().add(1, "hour");
  const reminder = defaultReminderFor({ startsAt, endsAt, allDay: false });
  const defaults = `start="${startsAt.format("YYYY-MM-DD HH:mm")}" end="${endsAt.format("YYYY-MM-DD HH:mm")}" status="public" timezone="${timezone}" reminders="${reminderToBBCode(reminder)}"`;
  return `[event ${defaults}]\n[/event]`;
}
