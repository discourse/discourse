(function($) {
  const DATE_TEMPLATE = `
    <span>
      <svg class="fa d-icon d-icon-globe-americas svg-icon" xmlns="http://www.w3.org/2000/svg">
        <use xlink:href="#globe-americas"></use>
      </svg>
      <span class="relative-time"></span>
    </span>
  `;

  const PREVIEW_TEMPLATE = `
    <div class='preview'>
      <span class='timezone'></span>
      <span class='date-time'></span>
    </div>
  `;

  function processElement($element, options = {}) {
    clearTimeout(this.timeout);

    const utc = moment().utc();
    const dateTime = options.time
      ? `${options.date} ${options.time}`
      : options.date;
    let utcDateTime;

    let displayedTimezone;
    if (options.time) {
      displayedTimezone = options.displayedTimezone || moment.tz.guess();
    } else {
      displayedTimezone =
        options.displayedTimezone || options.timezone || moment.tz.guess();
    }

    // if timezone given we convert date and time from given zone to Etc/UTC
    if (options.timezone) {
      utcDateTime = _applyZoneToDateTime(dateTime, options.timezone);
    } else {
      utcDateTime = moment.utc(dateTime);
    }

    if (utcDateTime < utc) {
      // if event is in the past we want to bump it no next occurrence when
      // recurring is set
      if (options.recurring) {
        utcDateTime = _applyRecurrence(utcDateTime, options.recurring);
      } else {
        $element.addClass("past");
      }
    }

    // once we have the correct UTC date we want
    // we adjust it to watching user timezone
    const adjustedDateTime = utcDateTime.tz(displayedTimezone);

    const previews = _generatePreviews(
      adjustedDateTime.clone(),
      displayedTimezone,
      options
    );
    const textPreview = _generateTextPreview(previews);
    const htmlPreview = _generateHtmlPreview(previews);

    const formatedDateTime = _applyFormatting(
      adjustedDateTime,
      displayedTimezone,
      options
    );

    $element
      .html(DATE_TEMPLATE)
      .attr("aria-label", textPreview)
      .attr(
        "data-html-tooltip",
        `<div class="locale-dates-previews">${htmlPreview}</div>`
      )
      .addClass("cooked-date")
      .find(".relative-time")
      .text(formatedDateTime);

    this.timeout = setTimeout(() => processElement($element, options), 10000);
  }

  function _formatTimezone(timezone) {
    return timezone
      .replace("_", " ")
      .replace("Etc/", "")
      .split("/");
  }

  function _zoneWithoutPrefix(timezone) {
    const parts = _formatTimezone(timezone);
    return parts[1] || parts[0];
  }

  function _applyZoneToDateTime(dateTime, timezone) {
    return moment.tz(dateTime, timezone).utc();
  }

  function _translateCalendarKey(time, key) {
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

  function _calendarFormats(time) {
    return {
      sameDay: _translateCalendarKey(time, "today"),
      nextDay: _translateCalendarKey(time, "tomorrow"),
      lastDay: _translateCalendarKey(time, "yesterday"),
      sameElse: "L"
    };
  }

  function _isEqualZones(timezoneA, timezoneB) {
    return (
      moment.tz(timezoneA).utcOffset() === moment.tz(timezoneB).utcOffset()
    );
  }

  function _applyFormatting(dateTime, displayedTimezone, options) {
    if (options.countdown) {
      const diffTime = dateTime.diff(moment());
      if (diffTime < 0) {
        return I18n.t("discourse_local_dates.relative_dates.countdown.passed");
      } else {
        return moment.duration(diffTime).humanize();
      }
    }

    const sameTimezone = _isEqualZones(displayedTimezone, moment.tz.guess());
    const inCalendarRange = dateTime.isBetween(
      moment().subtract(2, "days"),
      moment()
        .add(1, "days")
        .endOf("day")
    );

    if (options.calendar && inCalendarRange) {
      if (sameTimezone) {
        if (options.time) {
          dateTime = dateTime.calendar(null, _calendarFormats(options.time));
        } else {
          dateTime = dateTime.calendar(null, _calendarFormats(null));
        }
      } else {
        dateTime = dateTime.format(options.format);
        dateTime = dateTime.replace("TZ", "");
        dateTime = `${dateTime} (${_zoneWithoutPrefix(displayedTimezone)})`;
      }
    } else {
      if (options.time) {
        dateTime = dateTime.format(options.format);

        if (options.displayedTimezone && !sameTimezone) {
          dateTime = dateTime.replace("TZ", "");
          dateTime = `${dateTime} (${_zoneWithoutPrefix(displayedTimezone)})`;
        } else {
          dateTime = dateTime.replace(
            "TZ",
            _formatTimezone(displayedTimezone).join(": ")
          );
        }
      } else {
        dateTime = dateTime.format(options.format);

        if (!sameTimezone) {
          dateTime = dateTime.replace("TZ", "");
          dateTime = `${dateTime} (${_zoneWithoutPrefix(displayedTimezone)})`;
        } else {
          dateTime = dateTime.replace(
            "TZ",
            _zoneWithoutPrefix(displayedTimezone)
          );
        }
      }
    }

    return dateTime;
  }

  function _applyRecurrence(dateTime, recurring) {
    const parts = recurring.split(".");
    const count = parseInt(parts[0], 10);
    const type = parts[1];
    const diff = moment().diff(dateTime, type);
    const add = Math.ceil(diff + count);
    const wasDST = moment(dateTime.format()).isDST();
    let dateTimeWithRecurrence = dateTime.add(add, type);
    const isDST = moment(dateTimeWithRecurrence.format()).isDST();

    if (!wasDST && isDST) {
      dateTimeWithRecurrence.subtract(1, "hour");
    }

    if (wasDST && !isDST) {
      dateTimeWithRecurrence.add(1, "hour");
    }

    return dateTimeWithRecurrence;
  }

  function _createDateTimeRange(dateTime, timezone) {
    const dt = moment(dateTime).tz(timezone);

    return [dt.format("LLL"), "→", dt.add(24, "hours").format("LLL")].join(" ");
  }

  function _generatePreviews(dateTime, displayedTimezone, options) {
    const previewedTimezones = [];
    const watchingUserTimezone = moment.tz.guess();
    const timezones = options.timezones.filter(
      timezone => timezone !== watchingUserTimezone
    );

    previewedTimezones.push({
      timezone: watchingUserTimezone,
      current: true,
      dateTime: options.time
        ? moment(dateTime)
            .tz(watchingUserTimezone)
            .format("LLL")
        : _createDateTimeRange(dateTime, watchingUserTimezone)
    });

    if (
      options.timezone &&
      displayedTimezone === watchingUserTimezone &&
      options.timezone !== displayedTimezone &&
      !_isEqualZones(displayedTimezone, options.timezone)
    ) {
      timezones.unshift(options.timezone);
    }

    timezones
      .filter(z => z)
      .forEach(timezone => {
        if (_isEqualZones(timezone, displayedTimezone)) {
          return;
        }

        if (_isEqualZones(timezone, watchingUserTimezone)) {
          timezone = watchingUserTimezone;
        }

        previewedTimezones.push({
          timezone,
          dateTime: options.time
            ? moment(dateTime)
                .tz(timezone)
                .format("LLL")
            : _createDateTimeRange(dateTime, timezone)
        });
      });

    if (!previewedTimezones.length) {
      previewedTimezones.push({
        timezone: "Etc/UTC",
        dateTime: options.time
          ? moment(dateTime)
              .tz("Etc/UTC")
              .format("LLL")
          : _createDateTimeRange(dateTime, "Etc/UTC")
      });
    }

    return _.uniq(previewedTimezones, "timezone");
  }

  function _generateTextPreview(previews) {
    return previews
      .map(preview => {
        const formatedZone = _zoneWithoutPrefix(preview.timezone);

        if (preview.dateTime.match(/TZ/)) {
          return preview.dateTime.replace(/TZ/, formatedZone);
        } else {
          return `${formatedZone} ${preview.dateTime}`;
        }
      })
      .join(", ");
  }

  function _generateHtmlPreview(previews) {
    return previews
      .map(preview => {
        const $template = $(PREVIEW_TEMPLATE);

        if (preview.current) $template.addClass("current");

        $template.find(".timezone").text(_zoneWithoutPrefix(preview.timezone));
        $template.find(".date-time").text(preview.dateTime);
        return $template[0].outerHTML;
      })
      .join("");
  }

  $.fn.applyLocalDates = function() {
    return this.each(function() {
      const $element = $(this);

      const options = {};
      options.time = $element.attr("data-time");
      options.date = $element.attr("data-date");
      options.recurring = $element.attr("data-recurring");
      options.timezones = (
        $element.attr("data-timezones") ||
        Discourse.SiteSettings.discourse_local_dates_default_timezones ||
        "Etc/UTC"
      ).split("|");
      options.timezone = $element.attr("data-timezone");
      options.calendar = ($element.attr("data-calendar") || "on") === "on";
      options.displayedTimezone = $element.attr("data-displayed-timezone");
      options.format =
        $element.attr("data-format") || (options.time ? "LLL" : "LL");
      options.countdown = $element.attr("data-countdown");

      processElement($element, options);
    });
  };
})(jQuery);
