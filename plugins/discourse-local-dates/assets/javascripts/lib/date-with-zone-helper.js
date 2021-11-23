import { getProperties } from "@ember/object";

/*
  DateWithZoneHelper provides a limited list of helpers
  to manipulate a moment object with timezones

  - add(count unit) adds a COUNT of UNITS to a date
  - subtract(count unit) subtracts a COUNT of UNITS to a date
  - format(format) formats a date with zone in a consistent way, optional moment format
  - isDST() allows to know if a date in a specified timezone is currently under DST
  - datetimeWithZone(timezone) returns a new moment object with timezone applied
  - datetime returns the moment object
  - unitRepetitionsBetweenDates(duration, date) return the number of repetitions of
  duration between two dates, eg for duration: "1.weeks", "2.months"...
*/
export default class DateWithZoneHelper {
  constructor(params = {}) {
    this.timezone = params.timezone || "UTC";
    this.localTimezone = params.localTimezone || moment.tz.guess();

    this.datetime = moment.tz(
      getProperties(params, [
        "year",
        "month",
        "day",
        "hour",
        "minute",
        "second",
      ]),
      this.timezone
    );
  }

  isDST() {
    return this.datetime.tz(this.localTimezone).isDST();
  }

  unitRepetitionsBetweenDates(duration, date) {
    const [count, unit] = duration.split(".");
    // get the diff in the specified units with decimals
    const diff = Math.abs(this.datetime.diff(date, unit, true));
    // get integer count of duration in diff, eg: 4 hours diff is 2 for 2.hours duration
    const integer = Math.trunc(diff / count);
    // get fractional to define if we have to add one "duration"
    const fractional = (diff / count) % 1;

    return (
      integer * parseInt(count, 10) + (fractional > 0 ? parseInt(count, 10) : 0)
    );
  }

  add(count, unit) {
    return this._fromDatetime(
      this.datetime.clone().add(count, unit),
      this.timezone,
      this.localTimezone
    );
  }

  subtract(count, unit) {
    return this._fromDatetime(
      this.datetime.clone().subtract(count, unit),
      this.timezone,
      this.localTimezone
    );
  }

  datetimeWithZone(timezone) {
    return this.datetime.clone().tz(timezone);
  }

  format(format) {
    if (format) {
      return this.datetime.tz(this.localTimezone).format(format);
    }

    return this.datetime.tz(this.localTimezone).toISOString(true);
  }

  static fromDatetime(datetime, timezone, localTimezone) {
    return new DateWithZoneHelper({
      year: datetime.year(),
      month: datetime.month(),
      day: datetime.date(),
      hour: datetime.hour(),
      minute: datetime.minute(),
      second: datetime.second(),
      timezone,
      localTimezone,
    });
  }

  _fromDatetime(datetime, timezone, localTimezone) {
    return DateWithZoneHelper.fromDatetime(datetime, timezone, localTimezone);
  }
}
