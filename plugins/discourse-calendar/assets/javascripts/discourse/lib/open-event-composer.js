import moment from "moment";

export default async function openEventComposer({
  composer,
  currentUser,
  info,
  category,
}) {
  const timezone =
    currentUser?.user_option?.timezone || moment.tz.guess() || "UTC";

  const start = moment.parseZone(info.dateStr);
  if (info.allDay) {
    start.hour(9).minute(0);
  }

  const params = {
    start: start.format("YYYY-MM-DD HH:mm"),
    status: "public",
    timezone,
  };

  const markdown = Object.entries(params)
    .map(([key, value]) => `${key}="${value}"`)
    .join(" ");

  const body = `[event ${markdown}]\n[/event]\n`;

  await composer.openNewTopic({ body, category });
}
