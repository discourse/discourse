/* eslint-disable no-undef, no-unused-vars */
// note: this script uses the open.er-api.com service, it is only updated
// once every 24 hours, for more up to date rates see: https://www.exchangerate-api.com
function invoke(params) {
  const url = `https://open.er-api.com/v6/latest/${params.base_currency}`;
  const result = http.get(url);
  if (result.status !== 200) {
    return { error: "Failed to fetch exchange rates" };
  }
  const data = JSON.parse(result.body);
  const rate = data.rates[params.target_currency];
  if (!rate) {
    return { error: "Target currency not found" };
  }

  const rval = {
    base_currency: params.base_currency,
    target_currency: params.target_currency,
    exchange_rate: rate,
    last_updated: data.time_last_update_utc,
  };

  if (params.amount) {
    rval.original_amount = params.amount;
    rval.converted_amount = params.amount * rate;
  }

  return rval;
}

function details() {
  return "<a href='https://www.exchangerate-api.com'>Rates By Exchange Rate API</a>";
}
