const apiKey = "YOUR_OPENAI_API_KEY";

function invoke(params) {
  const prompt = params.prompt;
  const size = params.size || "1024x1024";

  const body = {
    model: "gpt-image-1",
    prompt,
    size,
    n: 1,
  };

  const result = http.post("https://api.openai.com/v1/images/generations", {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const responseData = JSON.parse(result.body);

  // Check for API errors
  if (responseData.error) {
    return {
      error: `OpenAI API Error: ${responseData.error.message || JSON.stringify(responseData.error)}`,
    };
  }

  // Validate response structure
  if (
    !responseData.data ||
    !responseData.data[0] ||
    !responseData.data[0].b64_json
  ) {
    return {
      error: "Unexpected API response format",
      status: result.status,
      body_preview: JSON.stringify(responseData).substring(0, 500),
    };
  }

  const base64Image = responseData.data[0].b64_json;
  const image = upload.create("generated_image.png", base64Image);
  const raw = `\n![${prompt}](${image.short_url})\n`;
  chain.setCustomRaw(raw);

  return { result: "Image generated successfully" };
}

function details() {
  return "Generates images using OpenAI's GPT Image 1 model.";
}
