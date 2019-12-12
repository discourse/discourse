export function getColors(count, palette) {
  palette = palette || "cool";
  let gradient;

  switch (palette) {
    case "cool":
      gradient = {
        0: [255, 255, 255],
        25: [220, 237, 200],
        50: [66, 179, 213],
        75: [26, 39, 62],
        100: [0, 0, 0]
      };
      break;
    case "warm":
      gradient = {
        0: [255, 255, 255],
        25: [254, 235, 101],
        50: [228, 82, 27],
        75: [77, 52, 47],
        100: [0, 0, 0]
      };
      break;
  }

  let gradientKeys = Object.keys(gradient);
  let colors = [];
  let currentGradientValue;
  let previousGradientIndex;

  for (let colorIndex = 0; colorIndex < count; colorIndex++) {
    currentGradientValue = (colorIndex + 1) * (100 / (count + 1));
    previousGradientIndex = previousGradientIndex || 0;
    let baseGradientKeyIndex;

    for (let y = previousGradientIndex; y < gradientKeys.length; y++) {
      if (!gradientKeys[y + 1]) {
        baseGradientKeyIndex = y - 1;
        break;
      } else if (
        currentGradientValue >= gradientKeys[y] &&
        currentGradientValue < gradientKeys[y + 1]
      ) {
        baseGradientKeyIndex = y;
        break;
      }
    }

    let differenceMultiplier =
      (currentGradientValue - gradientKeys[baseGradientKeyIndex]) /
      (gradientKeys[baseGradientKeyIndex + 1] -
        gradientKeys[baseGradientKeyIndex]);

    let color = [];
    for (let k = 0; k < 3; k++) {
      color.push(
        Math.round(
          gradient[gradientKeys[baseGradientKeyIndex]][k] -
            (gradient[gradientKeys[baseGradientKeyIndex]][k] -
              gradient[gradientKeys[baseGradientKeyIndex + 1]][k]) *
              differenceMultiplier
        )
      );
    }
    colors.push(`rgb(${color.toString()})`);
    previousGradientIndex = baseGradientKeyIndex;
  }
  return colors;
}
