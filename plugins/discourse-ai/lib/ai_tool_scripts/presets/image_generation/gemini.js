/* eslint-disable no-undef, no-unused-vars */
const apiKey = "YOUR_GOOGLE_API_KEY";

function invoke(params) {
  const prompt = params.prompt;
  const imageUrls = params.image_urls || [];

  // Determine mode: edit if image_urls provided, otherwise generate
  const isEditMode = imageUrls.length > 0;

  if (isEditMode) {
    return performEdit(prompt, imageUrls);
  } else {
    return performGeneration(prompt);
  }
}

function performGeneration(prompt) {
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

  return processResponse(result, prompt);
}

function performEdit(prompt, imageUrls) {
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
        mimeType: "image/png",
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

  return processResponse(result, prompt);
}

function processResponse(result, prompt) {
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

  return {
    result: "Image generated successfully",
  };
}

function details() {
  return "Generates and edits images using Gemini 2.5 Flash Image (Nano Banana). Supports generation mode (when no image_urls provided) and edit mode (when image_urls array is provided).";
}
