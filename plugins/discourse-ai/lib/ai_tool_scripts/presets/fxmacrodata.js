/* eslint-disable no-undef, no-unused-vars */
// note: without an API key FXMacroData serves USD only, on a 15 minute delay.
// For other currencies, add a credential with the alias "fxmacrodata_api_key"
// to this tool and uncomment the X-API-Key line below.
const BASE_URL = "https://api.fxmacrodata.com/v1";

function fetchJson(path) {
  const headers = {};
  // headers["X-API-Key"] = secrets.get("fxmacrodata_api_key");
  const result = http.get(`${BASE_URL}${path}`, { headers });
  let data = null;
  try {
    data = JSON.parse(result.body);
  } catch (e) {
    data = null;
  }
  return { status: result.status, data };
}

function invoke(params) {
  const currency = encodeURIComponent((params.currency || "USD").toLowerCase());
  const indicator = encodeURIComponent(params.indicator.toLowerCase());
  const limit = Math.min(Math.max(parseInt(params.limit, 10) || 5, 1), 50);

  const path = `/announcements/${currency}/${indicator}?limit=${limit}`;
  const result = fetchJson(path);
  if (result.status !== 200 || !result.data) {
    const detail = result.data && (result.data.detail || result.data.error);
    return { error: detail || "Failed to fetch indicator data" };
  }

  const data = result.data;
  const rval = {
    currency: data.currency,
    indicator: data.indicator,
    name: data.name,
    unit: data.value_metadata && data.value_metadata.source_unit,
    source: data.source,
    observations: (data.data || []).map((row) => ({
      date: row.date,
      value: row.val,
      released_at: row.announcement_datetime_local,
    })),
  };

  if (data.freemium_delay && data.freemium_delay.applied) {
    rval.freemium_delay = {
      message: data.freemium_delay.message,
      withheld_count: data.freemium_delay.withheld_count,
    };
  }

  const calendar = fetchJson(`/calendar/${currency}?indicator=${indicator}`);
  const next = calendar.status === 200 && calendar.data?.data?.[0];
  if (next) {
    rval.next_release = {
      scheduled_at: next.announcement_datetime_utc,
      reference_period: next.reference_period,
    };
  }

  return rval;
}

function details() {
  return "<a href='https://fxmacrodata.com/?utm_source=github&utm_medium=referral&utm_campaign=discourse&utm_content=docs'>Macro data provided by FXMacroData</a>";
}
