const apiKey = "YOUR_ADOBE_API_KEY";

function invoke(params) {
  const prompt = params.prompt;

  const body = {
    prompt,
    contentClass: "photo",
    size: {
      width: 1024,
      height: 1024,
    },
  };

  const result = http.post("https://firefly-api.adobe.io/v2/images/generate", {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "x-api-key": apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const base64Image = JSON.parse(result.body).outputs[0].image.base64;
  const image = upload.create("generated_image.png", base64Image);
  const raw = `\n![${prompt}](${image.short_url})\n`;
  chain.setCustomRaw(raw);

  return { result: "Image generated successfully" };
}

function details() {
  return "Generates images using Adobe Firefly.";
}
