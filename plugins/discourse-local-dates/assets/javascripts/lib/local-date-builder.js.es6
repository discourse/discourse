import I18n from "I18n";
import DateWithZoneHelper from "./date-with-zone-helper";

const TIME_FORMAT = "LLL";
const DATE_FORMAT = "LL";
const RANGE_SEPARATOR = "→";

export default class LocalDateBuilder {
  constructor(params = {}, localTimezone) {
    this.time = params.time;
    this.date = params.date;
    this.recurring = params.recurring;
    this.timezones = Array.from(
      new Set((params.timezones || []).filter(Boolean))
    );
    this.timezone = params.timezone || "UTC";
    this.calendar =
      typeof params.calendar === "undefined" ? true : params.calendar;
    this.displayedTimezone = params.displayedTimezone;
    this.format = params.format || (this.time ? TIME_FORMAT : DATE_FORMAT);
    this.countdown = params.countdown;
    this.localTimezone = localTimezone;
  }

  build() {
    const [year, month, day] = this.date.split("-").map(x => parseInt(x, 10));
    const [hour, minute] = (this.time || "")
      .split(":")
      .map(x => (x ? parseInt(x, 10) : undefined));

    let displayedTimezone;
    if (this.time) {
      displayedTimezone = this.displayedTimezone || this.localTimezone;
    } else {
      displayedTimezone =
        this.displayedTimezone || this.timezone || this.localTimezone;
    }

    let localDate = new DateWithZoneHelper({
      year,
      month: month ? month - 1 : null,
      day,
      hour,
      minute,
      timezone: this.timezone,
      localTimezone: this.localTimezone
    });

    if (this.recurring) {
      const [count, type] = this.recurring.split(".");

      const repetitionsForType = localDate.repetitionsBetweenDates(
        this.recurring,
        moment.tz(this.localTimezone)
      );

      localDate = localDate.add(repetitionsForType + parseInt(count, 10), type);
    }

    const previews = this._generatePreviews(localDate, displayedTimezone);

    return {
      pastEvent:
        !this.recurring &&
        moment.tz(this.localTimezone).isAfter(localDate.datetime),
      formated: this._applyFormatting(localDate, displayedTimezone),
      previews,
      textPreview: this._generateTextPreviews(previews)
    };
  }

  _generateTextPreviews(previews) {
    return previews
      .map(preview => {
        const formatedZone = this._zoneWithoutPrefix(preview.timezone);
        return `${formatedZone} ${preview.formated}`;
      })
      .join(", ");
  }

  _generatePreviews(localDate, displayedTimezone) {
    const previewedTimezones = [];

    const timezones = this.timezones.filter(
      timezone =>
        !this._isEqualZones(timezone, this.localTimezone) &&
        !this._isEqualZones(timezone, this.timezone)
    );

    previewedTimezones.push({
      timezone: this._zoneWithoutPrefix(this.localTimezone),
      current: true,
      formated: this._createDateTimeRange(
        DateWithZoneHelper.fromDatetime(
          localDate.datetime,
          localDate.timezone,
          this.localTimezone
        ),
        this.time
      )
    });

    if (
      this.timezone &&
      displayedTimezone === this.localTimezone &&
      this.timezone !== displayedTimezone &&
      !this._isEqualZones(displayedTimezone, this.timezone)
    ) {
      timezones.unshift(this.timezone);
    }

    timezones.forEach(timezone => {
      if (this._isEqualZones(timezone, displayedTimezone)) {
        return;
      }

      if (this._isEqualZones(timezone, this.localTimezone)) {
        timezone = this.localTimezone;
      }

      previewedTimezones.push({
        timezone: this._zoneWithoutPrefix(timezone),
        formated: this._createDateTimeRange(
          DateWithZoneHelper.fromDatetime(
            localDate.datetime,
            localDate.timezone,
            timezone
          ),
          this.time
        )
      });
    });

    return previewedTimezones.uniqBy("timezone");
  }

  _isEqualZones(timezoneA, timezoneB) {
    if ((timezoneA || timezoneB) && (!timezoneA || !timezoneB)) {
      return false;
    }

    if (timezoneA.includes(timezoneB) || timezoneB.includes(timezoneA)) {
      return true;
    }

    return (
      moment.tz(timezoneA).utcOffset() === moment.tz(timezoneB).utcOffset()
    );
  }

  _createDateTimeRange(startRange, time) {
    // if a time has been given we do not attempt to automatically create a range
    // instead we show only one date with a format showing the time
    if (time) {
      return startRange.format(TIME_FORMAT);
    } else {
      const endRange = startRange.add(24, "hours");
      return [
        startRange.format("LLLL"),
        RANGE_SEPARATOR,
        endRange.format("LLLL")
      ].join(" ");
    }
  }

  _applyFormatting(localDate, displayedTimezone) {
    if (this.countdown) {
      const diffTime = moment.tz(this.localTimezone).diff(localDate.datetime);

      if (diffTime < 0) {
        return moment.duration(diffTime).humanize();
      } else {
        return I18n.t("discourse_local_dates.relative_dates.countdown.passed");
      }
    }

    const sameTimezone = this._isEqualZones(
      displayedTimezone,
      this.localTimezone
    );

    if (this.calendar) {
      const inCalendarRange = moment
        .tz(this.localTimezone)
        .isBetween(
          localDate.subtract(2, "day").datetime,
          localDate.add(1, "day").datetime.endOf("day")
        );

      if (inCalendarRange && sameTimezone) {
        return localDate
          .datetimeWithZone(this.localTimezone)
          .calendar(
            moment.tz(localDate.timezone),
            this._calendarFormats(this.time ? this.time : null)
          );
      }
    }

    if (!sameTimezone) {
      return this._formatWithZone(localDate, displayedTimezone, this.format);
    }

    return localDate.format(this.format);
  }

  _calendarFormats(time) {
    return {
      sameDay: this._translateCalendarKey(time, "today"),
      nextDay: this._translateCalendarKey(time, "tomorrow"),
      lastDay: this._translateCalendarKey(time, "yesterday"),
      sameElse: "L"
    };
  }

  _translateCalendarKey(time, key) {
    const translated = I18n.t(`discourse_local_dates.relative_dates.${key}`, {
      time: "LT"
    });

    if (time) {
      return translated
        .split("LT")
        .map(w => `[${w}]`)
        .join("LT");
    } else {
      return `[${translated.replace(" LT", "")}]`;
    }
  }

  _formatTimezone(timezone) {
    return timezone
      .replace("_", " ")
      .replace("Etc/", "")
      .split("/");
  }

  _zoneWithoutPrefix(timezone) {
    const [part1, part2] = this._formatTimezone(timezone);
    return part2 || part1;
  }

  _formatWithZone(localDate, displayedTimezone, format) {
    let formated = localDate.datetimeWithZone(displayedTimezone).format(format);
    return `${formated} (${this._zoneWithoutPrefix(displayedTimezone)})`;
  }
}
