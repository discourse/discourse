/* eslint-disable no-undef, no-unused-vars */
const apiKey = "YOUR_KEY";
const model = "black-forest-labs/FLUX.1.1-pro";

function invoke(params) {
  const prompt = params.prompt;
  const imageUrls = params.image_urls || [];

  // Determine mode: edit if image_urls provided, otherwise generate
  const isEditMode = imageUrls.length > 0;

  let seed = parseInt(params.seed, 10);
  if (!(seed > 0)) {
    seed = Math.floor(Math.random() * 1000000) + 1;
  }

  if (isEditMode) {
    return performEdit(prompt, imageUrls, seed);
  } else {
    return performGeneration(prompt, seed);
  }
}

function performGeneration(prompt, seed) {
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

  const responseData = JSON.parse(result.body);

  // Check for API errors
  if (responseData.error) {
    return {
      error: `Together.ai API Error: ${responseData.error.message || JSON.stringify(responseData.error)}`,
    };
  }

  if (
    !responseData.data ||
    !responseData.data[0] ||
    !responseData.data[0].b64_json
  ) {
    return {
      error: "Unexpected API response format",
      body_preview: JSON.stringify(responseData).substring(0, 500),
    };
  }

  const base64Image = responseData.data[0].b64_json;
  const image = upload.create("generated_image.png", base64Image);
  const raw = `\n![${prompt}](${image.short_url})\n`;
  chain.setCustomRaw(raw);

  return { result: "Image generated successfully", seed };
}

function performEdit(prompt, imageUrls, seed) {
  // FLUX supports img2img via image_url parameter
  // Together.ai expects a single image URL (uses first one)
  const imageUrl = imageUrls[0];

  // Convert short URL to full CDN URL
  const fullImageUrl = upload.getUrl(imageUrl);
  if (!fullImageUrl) {
    return { error: `Failed to get full URL for: ${imageUrl}` };
  }

  const body = {
    model,
    prompt,
    width: 1024,
    height: 768,
    steps: 28, // Use more steps for img2img
    n: 1,
    seed,
    response_format: "b64_json",
    image_url: fullImageUrl,
  };

  const result = http.post("https://api.together.xyz/v1/images/generations", {
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
      error: `Together.ai API Error: ${responseData.error.message || JSON.stringify(responseData.error)}`,
    };
  }

  if (
    !responseData.data ||
    !responseData.data[0] ||
    !responseData.data[0].b64_json
  ) {
    return {
      error: "Unexpected API response format",
      body_preview: JSON.stringify(responseData).substring(0, 500),
    };
  }

  const base64Image = responseData.data[0].b64_json;
  const image = upload.create("edited_image.png", base64Image);
  const raw = `\n![${prompt}](${image.short_url})\n`;
  chain.setCustomRaw(raw);

  return { result: "Image edited successfully", seed };
}

function details() {
  return "Generates and edits images using the FLUX 1.1 Pro model via Together.ai. Supports generation mode (when no image_urls provided) and img2img edit mode (when image_urls array is provided, uses first image).";
}
