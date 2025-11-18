/* eslint-disable no-undef, no-unused-vars */
const apiKey = "YOUR_KEY";
const model = "black-forest-labs/FLUX.1.1-pro";

function invoke(params) {
  let seed = parseInt(params.seed, 10);
  if (!(seed > 0)) {
    seed = Math.floor(Math.random() * 1000000) + 1;
  }

  const prompt = params.prompt;
  const body = {
    model,
    prompt,
    width: 1024,
    height: 768,
    steps: 10,
    n: 1,
    seed,
    response_format: "b64_json",
  };

  const result = http.post("https://api.together.xyz/v1/images/generations", {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const base64Image = JSON.parse(result.body).data[0].b64_json;
  const image = upload.create("generated_image.png", base64Image);
  const raw = `\n![${prompt}](${image.short_url})\n`;
  chain.setCustomRaw(raw);

  return { result: "Image generated successfully", seed };
}

function details() {
  return "Generates images based on a text prompt using the FLUX model.";
}
