function emptyPeriodRow(period) {
  return {
    period,
    total_tokens: 0,
    total_cache_read_tokens: 0,
    total_cache_write_tokens: 0,
    total_request_tokens: 0,
    total_response_tokens: 0,
  };
}

export function normalizeAiUsageTimeSeriesData(data, period, dateRange = {}) {
  if (!data?.length) {
    return [];
  }

  const normalized = [];
  let interval;
  let format;

  if (period === "hour") {
    interval = "hour";
    format = "YYYY-MM-DD HH:00:00";
  } else if (period === "day") {
    interval = "day";
    format = "YYYY-MM-DD";
  } else {
    interval = "month";
    format = "YYYY-MM";
  }

  const periodMoments = data.map((row) => moment(row.period));
  const rangeStart = moment(dateRange.start);
  const rangeEnd = moment(dateRange.end);
  const startCandidates = [rangeStart, ...periodMoments].filter((date) =>
    date.isValid()
  );
  const endCandidates = [rangeEnd, ...periodMoments].filter((date) =>
    date.isValid()
  );
  const startDate = moment.min(startCandidates);
  const endDate = moment.max(endCandidates);

  const dataMap = new Map(
    data.map((row) => [moment(row.period).format(format), row])
  );

  for (
    let currentMoment = moment(startDate);
    currentMoment.isSameOrBefore(endDate);
    currentMoment.add(1, interval)
  ) {
    const dateKey = currentMoment.format(format);
    const existingData = dataMap.get(dateKey);

    normalized.push(existingData || emptyPeriodRow(currentMoment.format()));
  }

  if (normalized.length === 1) {
    const periodMoment = moment(normalized[0].period);

    return [
      emptyPeriodRow(periodMoment.clone().subtract(1, interval).format()),
      normalized[0],
      emptyPeriodRow(periodMoment.clone().add(1, interval).format()),
    ];
  }

  return normalized;
}
