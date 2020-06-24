const { getProperties } = Ember;

/*
  DateWithZoneHelper provides a limited list of helpers
  to manipulate a moment object with timezones

  - add(count unit) adds a COUNT of UNITS to a date
  - subtract(count unit) subtracts a COUNT of UNITS to a date
  - format(format) formats a date with zone in a consitent way, optional moment format
  - isDST() allows to know if a date in a specified timezone is currently under DST
  - datetimeWithZone(timezone) returns a new moment object with timezone applied
  - datetime returns the moment object
  - repetitionsBetweenDates(duration, date) return the number of repertitions of
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
        "second"
      ]),
      this.timezone
    );
  }

  isDST() {
    return this.datetime.tz(this.localTimezone).isDST();
  }

  repetitionsBetweenDates(duration, date) {
    const [count, unit] = duration.split(".");
    const diff = this.datetime.diff(date, unit);
    const repetitions = diff / parseInt(count, 10);
    return Math.abs((Math.round(repetitions * 10) / 10).toFixed(1));
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
      localTimezone
    });
  }

  _fromDatetime(datetime, timezone, localTimezone) {
    return DateWithZoneHelper.fromDatetime(datetime, timezone, localTimezone);
  }
}
