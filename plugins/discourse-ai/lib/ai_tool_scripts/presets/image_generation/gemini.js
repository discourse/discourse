const apiKey = "YOUR_GOOGLE_API_KEY";

function invoke(params) {
  const prompt = params.prompt;

  const body = {
    contents: [
      {
        parts: [{ text: prompt }],
      },
    ],
    generationConfig: {
      responseModalities: ["Image"],
    },
  };

  const result = http.post(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent`,
    {
      headers: {
        "x-goog-api-key": `${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }
  );

  const responseData = JSON.parse(result.body);

  // Check for API errors
  if (responseData.error) {
    return {
      error: `Gemini API Error: ${responseData.error.message || JSON.stringify(responseData.error)}`,
    };
  }

  // Validate response structure
  if (
    !responseData.candidates ||
    !responseData.candidates[0] ||
    !responseData.candidates[0].content ||
    !responseData.candidates[0].content.parts
  ) {
    return {
      error: "Unexpected API response format",
      status: result.status,
      body_preview: JSON.stringify(responseData).substring(0, 500),
    };
  }

  // Find the part with inlineData
  const parts = responseData.candidates[0].content.parts;
  let base64Image = null;

  for (const part of parts) {
    if (part.inlineData && part.inlineData.data) {
      base64Image = part.inlineData.data;
      break;
    }
  }

  if (!base64Image) {
    return {
      error: "No image data found in response",
      parts_preview: JSON.stringify(parts).substring(0, 500),
    };
  }

  const image = upload.create("generated_image.png", base64Image);
  const raw = `\n![${prompt}](${image.short_url})\n`;
  chain.setCustomRaw(raw);

  return { result: "Image generated successfully" };
}

function details() {
  return "Generates images using Gemini 2.5 Flash Image (Nano Banana).";
}
