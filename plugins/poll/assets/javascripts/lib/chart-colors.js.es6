export function getColors(count, palette) {
  palette = palette || "cool";
  let gradient;

  switch (palette) {
    case "cool":
      gradient = {
        0: [255, 255, 255, 1],
        20: [220, 237, 200, 1],
        45: [66, 179, 213, 1],
        65: [26, 39, 62, 1],
        100: [0, 0, 0, 1]
      };
      break;
    case "warm":
      gradient = {
        0: [255, 255, 255, 1],
        20: [254, 235, 101, 1],
        45: [228, 82, 27, 1],
        65: [77, 52, 47, 1],
        100: [0, 0, 0, 1]
      };
      break;
    case "neon":
      gradient = {
        0: [255, 255, 255, 1],
        20: [255, 236, 179, 1],
        45: [232, 82, 133, 1],
        65: [106, 27, 154, 1],
        100: [0, 0, 0, 1]
      };
      break;
  }

  //Get a sorted array of the gradient keys
  let gradientKeys = Object.keys(gradient);
  gradientKeys.sort(function(a, b) {
    return +a - +b;
  });

  //Calculate colors
  let colors = [];
  for (let i = 0; i < count; i++) {
    let gradientIndex = (i + 1) * (100 / (count + 1)); //Find where to get a color from the gradient
    for (let j = 0; j < gradientKeys.length; j++) {
      let gradientKey = gradientKeys[j];
      if (gradientIndex === +gradientKey) {
        //Exact match with a gradient key - just get that color
        colors[i] = "rgba(" + gradient[gradientKey].toString() + ")";
        break;
      } else if (gradientIndex < +gradientKey) {
        //It's somewhere between this gradient key and the previous
        let prevKey = gradientKeys[j - 1];
        let gradientPartIndex =
          (gradientIndex - prevKey) / (gradientKey - prevKey); //Calculate where
        let color = [];
        for (let k = 0; k < 4; k++) {
          //Loop through Red, Green, Blue and Alpha and calculate the correct color and opacity
          color.push(
            gradient[prevKey][k] -
              (gradient[prevKey][k] - gradient[gradientKey][k]) *
                gradientPartIndex
          );
          if (k < 3) color[k] = Math.round(color[k]);
        }
        colors[i] = "rgba(" + color.toString() + ")";
      }
    }
  }
  return colors;
}
