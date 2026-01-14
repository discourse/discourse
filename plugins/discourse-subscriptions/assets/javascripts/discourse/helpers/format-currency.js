export default function formatCurrency(currency, amount) {
  let currencySign;

  switch (currency.toUpperCase()) {
    case "EUR":
      currencySign = "€";
      break;
    case "GBP":
      currencySign = "£";
      break;
    case "INR":
      currencySign = "₹";
      break;
    case "BRL":
      currencySign = "R$";
      break;
    case "DKK":
      currencySign = "DKK";
      break;
    case "SGD":
      currencySign = "S$";
      break;
    case "ZAR":
      currencySign = "R";
      break;
    case "CHF":
      currencySign = "CHF";
      break;
    case "PLN":
      currencySign = "zł";
      break;
    case "CZK":
      currencySign = "Kč";
      break;
    case "SEK":
      currencySign = "kr";
      break;
    default:
      currencySign = "$";
  }

  const formattedAmount = parseFloat(amount).toFixed(2);
  return currencySign + formattedAmount;
}
