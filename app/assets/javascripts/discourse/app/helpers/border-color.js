const validDirections = ["top", "right", "bottom", "left"];

export default function borderColor(color, direction) {
  const borderProperty =
    direction && validDirections.includes(direction)
      ? `border-${direction}-color`
      : "border-color";

  return `${borderProperty}: #${color} `;
}
