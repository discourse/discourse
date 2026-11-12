/* eslint-disable no-undef, no-unused-vars */
// `model` is defined by the preset that includes this script.
const apiKey = secrets.get("google_api_key");

function invoke(params) {
  const prompt = params.prompt;
  const aspectRatio = params.aspect_ratio;
  const imageUrls = params.image_urls || [];

  // Determine mode: edit if image_urls provided, otherwise generate
  const isEditMode = imageUrls.length > 0;

  if (isEditMode) {
    return performEdit(prompt, imageUrls, aspectRatio);
  } else {
    return performGeneration(prompt, aspectRatio);
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

function generationConfig(aspectRatio) {
  const config = { responseModalities: ["Image"] };
  if (aspectRatio) {
    config.imageConfig = { aspectRatio };
  }
  return config;
}

function performGeneration(prompt, aspectRatio) {
  const body = {
    contents: [
      {
        parts: [{ text: prompt }],
      },
    ],
    generationConfig: generationConfig(aspectRatio),
  };

  const result = http.post(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      headers: {
        "x-goog-api-key": `${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }
  );

  return processResponse(result, prompt);
}

function performEdit(prompt, imageUrls, aspectRatio) {
  // Gemini supports multimodal input - include images in the parts array
  // Limit to first 10 images
  const imagesToEdit = imageUrls.slice(0, 10);
  const parts = [];

  // Add each image as inline data
  for (const imageUrl of imagesToEdit) {
    const base64Data = upload.getBase64(imageUrl);
    if (!base64Data) {
      return { error: `Failed to fetch image data for: ${imageUrl}` };
    }

    parts.push({
      inlineData: {
        mimeType: detectImageMimeType(base64Data, imageUrl),
        data: base64Data,
      },
    });
  }

  // Add the text prompt after the images
  parts.push({ text: prompt });

  const body = {
    contents: [
      {
        parts,
      },
    ],
    generationConfig: generationConfig(aspectRatio),
  };

  const result = http.post(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      headers: {
        "x-goog-api-key": `${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    }
  );

  return processResponse(result, prompt);
}

function processResponse(result, prompt) {
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
  let mimeType = null;

  for (const part of parts) {
    if (part.inlineData && part.inlineData.data) {
      base64Image = part.inlineData.data;
      mimeType = part.inlineData.mimeType;
      break;
    }
  }

  if (!base64Image) {
    return {
      error: "No image data found in response",
      parts_preview: JSON.stringify(parts).substring(0, 500),
    };
  }

  const extension = mimeType === "image/jpeg" ? "jpg" : "png";
  const image = upload.create(`generated_image.${extension}`, base64Image);

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
  return `Generates and edits images using Google's ${model} model. Supports generation mode (when no image_urls provided) and edit mode (when image_urls array is provided).`;
}
