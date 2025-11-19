/* eslint-disable no-undef, no-unused-vars */
function invoke(params) {
  const apiKey = "YOUR_ALPHAVANTAGE_API_KEY"; // Replace with your actual API key
  const url = `https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=${params.symbol}&apikey=${apiKey}`;

  const result = http.get(url);
  if (result.status !== 200) {
    return { error: "Failed to fetch stock quote" };
  }

  const data = JSON.parse(result.body);
  if (data["Error Message"]) {
    return { error: data["Error Message"] };
  }

  const quote = data["Global Quote"];
  if (!quote || Object.keys(quote).length === 0) {
    return { error: "No data found for the given symbol" };
  }

  return {
    symbol: quote["01. symbol"],
    price: parseFloat(quote["05. price"]),
    change: parseFloat(quote["09. change"]),
    change_percent: quote["10. change percent"],
    volume: parseInt(quote["06. volume"], 10),
    latest_trading_day: quote["07. latest trading day"],
  };
}

function details() {
  return "<a href='https://www.alphavantage.co'>Stock data provided by AlphaVantage</a>";
}
