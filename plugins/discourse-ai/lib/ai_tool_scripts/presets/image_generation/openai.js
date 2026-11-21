/* eslint-disable no-undef, no-unused-vars */
// `model` is defined by the preset that includes this script.
const apiKey = secrets.get("openai_api_key");

function invoke(params) {
  const prompt = params.prompt;
  const size = params.size || "1024x1024";
  const quality = params.quality || "auto";
  const imageUrls = params.image_urls || [];

  // Determine mode: edit if image_urls provided, otherwise generate
  const isEditMode = imageUrls.length > 0;

  if (isEditMode) {
    return performEdit(prompt, size, quality, imageUrls);
  } else {
    return performGeneration(prompt, size, quality);
  }
}

function detectImageMimeType(base64Data, imageUrl) {
  if (base64Data.startsWith("/9j/")) {
    return "image/jpeg";
  }
  if (base64Data.startsWith("iVBOR")) {
    return "image/png";
  }
  if (/\.jpe?g$/i.test(imageUrl)) {
    return "image/jpeg";
  }
  return "image/png";
}

function parseJsonResponse(result) {
  try {
    const data = JSON.parse(result.body);
    if (data && typeof data === "object" && !Array.isArray(data)) {
      return data;
    }
  } catch {
    // Handled below as unexpected response format
  }
  return null;
}

function performGeneration(prompt, size, quality) {
  const body = {
    model,
    prompt,
    size,
    quality,
    n: 1,
  };

  const result = http.post("https://api.openai.com/v1/images/generations", {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  return processResponse(result, prompt, "generated_image.png");
}

function performEdit(prompt, size, quality, imageUrls) {
  // Fetch base64 data for all images (limit to 16 per OpenAI API)
  const imagesToEdit = imageUrls.slice(0, 16);
  const images = [];

  for (const imageUrl of imagesToEdit) {
    const base64Data = upload.getBase64(imageUrl);
    if (!base64Data) {
      return { error: `Failed to fetch image data for: ${imageUrl}` };
    }
    const mimeType = detectImageMimeType(base64Data, imageUrl);
    images.push({
      image_url: `data:${mimeType};base64,${base64Data}`,
    });
  }

  const body = {
    model,
    prompt,
    size,
    quality,
    n: 1,
    images,
  };

  const result = http.post("https://api.openai.com/v1/images/edits", {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  return processResponse(result, prompt, "edited_image.png");
}

function processResponse(result, prompt, filename) {
  const responseData = parseJsonResponse(result);
  if (!responseData) {
    return {
      error: "Unexpected API response format",
      status: result.status,
      body_preview: String(result.body || "").substring(0, 500),
    };
  }

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
  const image = upload.create(filename, base64Image);

  if (!image || image.error) {
    return {
      error: `Failed to create upload: ${image ? image.error : "upload.create returned null"}`,
    };
  }

  if (!image.short_url) {
    return {
      error: "Upload created but short_url is missing",
    };
  }

  const raw = `\n![${prompt}](${image.short_url})\n`;
  chain.setCustomRaw(raw);

  return { url: image.short_url };
}

function details() {
  return `Generates and edits images using OpenAI's ${model} model. Supports generation mode (when no image_urls provided) and edit mode (when image_urls array is provided).`;
}
