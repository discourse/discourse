/* eslint-disable no-undef, no-unused-vars */
const apiKey = "YOUR_OPENAI_API_KEY";

function invoke(params) {
  const prompt = params.prompt;
  const size = params.size || "1024x1024";
  const imageUrls = params.image_urls || [];

  // Determine mode: edit if image_urls provided, otherwise generate
  const isEditMode = imageUrls.length > 0;

  if (isEditMode) {
    return performEdit(prompt, size, imageUrls);
  } else {
    return performGeneration(prompt, size);
  }
}

function performGeneration(prompt, size) {
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

function performEdit(prompt, size, imageUrls) {
  // Fetch base64 data for all images (limit to 16 per OpenAI API)
  const imagesToEdit = imageUrls.slice(0, 16);
  const imageDataArray = [];

  for (const imageUrl of imagesToEdit) {
    const base64Data = upload.getBase64(imageUrl);
    if (!base64Data) {
      return { error: `Failed to fetch image data for: ${imageUrl}` };
    }
    imageDataArray.push(base64Data);
  }

  // Build multipart form data manually
  const boundary = `----FormBoundary${Date.now()}`;
  let body = "";

  // Add model field
  body += `--${boundary}\r\n`;
  body += `Content-Disposition: form-data; name="model"\r\n\r\n`;
  body += `gpt-image-1\r\n`;

  // Add image fields
  for (let i = 0; i < imageDataArray.length; i++) {
    body += `--${boundary}\r\n`;
    body += `Content-Disposition: form-data; name="image[]"; filename="image_${i}.png"\r\n`;
    body += `Content-Type: image/png\r\n`;
    body += `Content-Transfer-Encoding: base64\r\n\r\n`;
    body += `${imageDataArray[i]}\r\n`;
  }

  // Add prompt field
  body += `--${boundary}\r\n`;
  body += `Content-Disposition: form-data; name="prompt"\r\n\r\n`;
  body += `${prompt}\r\n`;

  // Add size field if provided
  if (size) {
    body += `--${boundary}\r\n`;
    body += `Content-Disposition: form-data; name="size"\r\n\r\n`;
    body += `${size}\r\n`;
  }

  // Add n field (always 1 for edits)
  body += `--${boundary}\r\n`;
  body += `Content-Disposition: form-data; name="n"\r\n\r\n`;
  body += `1\r\n`;

  // End boundary
  body += `--${boundary}--\r\n`;

  const result = http.post("https://api.openai.com/v1/images/edits", {
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": `multipart/form-data; boundary=${boundary}`,
    },
    body,
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
  const image = upload.create("edited_image.png", base64Image);
  const raw = `\n![${prompt}](${image.short_url})\n`;
  chain.setCustomRaw(raw);

  return { result: "Image edited successfully" };
}

function details() {
  return "Generates and edits images using OpenAI's GPT Image 1 model. Supports generation mode (when no image_urls provided) and edit mode (when image_urls array is provided).";
}
