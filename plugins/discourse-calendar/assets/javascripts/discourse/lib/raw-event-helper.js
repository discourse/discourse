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

export function replaceRaw(params, raw) {
  const eventRegex = /\[event (.*?)\](.*?)\[\/event\]/s;
  const eventMatches = raw.match(eventRegex);

  if (eventMatches && eventMatches[1]) {
    const markdownParams = [];

    let description = params.description;
    description = description ? `${description}\n` : "";
    delete params.description;

    Object.keys(params).forEach((param) => {
      const value = params[param];
      if (value != null && value !== "" && String(value).trim() !== "") {
        markdownParams.push(`${param}="${value.replace(/"/g, "")}"`);
      }
    });

    return raw.replace(
      eventRegex,
      `[event ${markdownParams.join(" ")}]\n${description}[/event]`
    );
  }

  return false;
}

export function camelCase(input) {
  return input
    .toLowerCase()
    .replace(/-/g, "_")
    .replace(/_(.)/g, function (match, group1) {
      return group1.toUpperCase();
    });
}

export function removeEvent(raw) {
  return raw.replace(/\[event (.*?)\](.*?)\[\/event\]/s, "");
}
