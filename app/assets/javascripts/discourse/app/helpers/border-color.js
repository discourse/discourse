import { htmlHelper } from "discourse-common/lib/helpers";

const validDirections = ["top", "right", "bottom", "left"];

export default htmlHelper((color, direction) => {
  const borderColor = `#${color}`;

  const borderProperty =
    direction && validDirections.includes(direction)
      ? `border-${direction}-color`
      : "border-color";

  return `${borderProperty}: ${borderColor} `;
});
