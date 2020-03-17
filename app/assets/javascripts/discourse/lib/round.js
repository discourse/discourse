import decimalAdjust from "discourse/lib/decimal-adjust";

export default function(value, exp) {
  return decimalAdjust("round", value, exp);
}
