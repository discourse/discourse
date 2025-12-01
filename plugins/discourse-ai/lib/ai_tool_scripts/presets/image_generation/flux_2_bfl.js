/* eslint-disable no-undef, no-unused-vars */
const apiKey = "YOUR_BFL_API_KEY";

function invoke(params) {
  const prompt = params.prompt;
  const imageUrls = params.image_urls || [];

  let seed = parseInt(params.seed, 10);
  if (!(seed > 0)) {
    seed = Math.floor(Math.random() * 2147483647) + 1;
  }

  if (imageUrls.length > 0) {
    return performEdit(prompt, imageUrls, seed);
  } else {
    return performGeneration(prompt, seed);
  }
}

function performGeneration(prompt, seed) {
  const body = {
    prompt,
    seed,
    width: 1024,
    height: 1024,
    output_format: "png",
    safety_tolerance: 2,
  };

  return submitAndPoll(body, prompt, seed);
}

function performEdit(prompt, imageUrls, seed) {
  const body = {
    prompt,
    seed,
    output_format: "png",
    safety_tolerance: 2,
  };

  // Add up to 10 reference images as base64
  const maxImages = Math.min(imageUrls.length, 10);
  for (let i = 0; i < maxImages; i++) {
    const base64Data = upload.getBase64(imageUrls[i]);
    if (!base64Data) {
      return { error: `Failed to get base64 data for: ${imageUrls[i]}` };
    }
    const paramName = i === 0 ? "input_image" : `input_image_${i + 1}`;
    body[paramName] = base64Data;
  }

  return submitAndPoll(body, prompt, seed);
}

function submitAndPoll(body, prompt, seed) {
  // Submit request
  const submitResult = http.post("https://api.bfl.ai/v1/flux-2-pro", {
    headers: {
      "x-key": apiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  const submitData = JSON.parse(submitResult.body);

  if (submitData.error) {
    return { error: `BFL API Error: ${submitData.error}` };
  }

  if (!submitData.id) {
    return {
      error: "No task ID returned",
      body_preview: JSON.stringify(submitData).substring(0, 500),
    };
  }

  // Poll for result (max 25 attempts × 3s = 75s)
  const pollingUrl = `https://api.bfl.ai/v1/get_result?id=${submitData.id}`;

  for (let attempt = 0; attempt < 25; attempt++) {
    const pollResult = http.get(pollingUrl, {
      headers: { "x-key": apiKey },
    });

    const pollData = JSON.parse(pollResult.body);

    if (pollData.status === "Ready") {
      // Download image from signed URL
      const imageUrl = pollData.result.sample;
      const imageResponse = http.get(imageUrl, { base64Encode: true });

      if (!imageResponse.body) {
        return { error: "Failed to download generated image" };
      }

      const image = upload.create("generated_image.png", imageResponse.body);

      if (!image || image.error) {
        return {
          error: `Upload failed: ${image ? image.error : "unknown"}`,
        };
      }

      const raw = `\n![${prompt}](${image.short_url})\n`;
      chain.setCustomRaw(raw);

      return { result: "Image generated successfully", seed };
    }

    if (
      pollData.status === "Failed" ||
      pollData.status === "Error" ||
      pollData.status === "Request Moderated"
    ) {
      return {
        error: `Generation failed: ${pollData.error || pollData.status}`,
      };
    }

    // Wait 3 seconds before next poll
    sleep(3000);
  }

  return { error: "Generation timed out after 75 seconds" };
}

function details() {
  return "Generates and edits images using FLUX 2 Pro via Black Forest Labs API. Supports multi-image editing with up to 10 reference images.";
}
