import moment from "moment";

const DEFAULT_ALL_DAY_START_HOUR = 9;

function allDayStartTime(siteSettings) {
  const [hour, minute] = (siteSettings?.all_day_event_start_time || "").split(
    ":"
  );
  const parsedHour = parseInt(hour, 10);

  if (isNaN(parsedHour)) {
    return { hour: DEFAULT_ALL_DAY_START_HOUR, minute: 0 };
  }

  return { hour: parsedHour, minute: parseInt(minute, 10) || 0 };
}

export default async function openEventComposer({
  composer,
  currentUser,
  siteSettings,
  info,
  category,
}) {
  const timezone =
    currentUser?.user_option?.timezone || moment.tz.guess() || "UTC";

  const start = moment.parseZone(info.dateStr);
  if (info.allDay) {
    const { hour, minute } = allDayStartTime(siteSettings);
    start.hour(hour).minute(minute);
  }

  const end = start.clone().add(1, "hour");

  const params = {
    start: start.format("YYYY-MM-DD HH:mm"),
    status: "public",
    timezone,
    end: end.format("YYYY-MM-DD HH:mm"),
  };

  const markdown = Object.entries(params)
    .map(([key, value]) => `${key}="${value}"`)
    .join(" ");

  const body = `[event ${markdown}]\n[/event]\n`;

  await composer.openNewTopic({ body, category });
}
