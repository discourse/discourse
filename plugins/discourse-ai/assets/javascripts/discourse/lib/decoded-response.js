export function isValidDecodedToolCall(toolCall) {
  return Boolean(
    toolCall &&
    typeof toolCall === "object" &&
    !Array.isArray(toolCall) &&
    typeof toolCall.name === "string" &&
    Object.hasOwn(toolCall, "arguments")
  );
}

export function isValidDecodedToolResult(toolResult) {
  return Boolean(
    toolResult &&
    typeof toolResult === "object" &&
    !Array.isArray(toolResult) &&
    Object.hasOwn(toolResult, "result")
  );
}

export function isDecodedResponse(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }

  const hasThinking =
    typeof value.thinking === "string" && value.thinking.length > 0;
  const hasResponse =
    typeof value.response === "string" && value.response.length > 0;
  const hasToolCalls =
    Array.isArray(value.tool_calls) &&
    value.tool_calls.some(isValidDecodedToolCall);
  const hasToolResults =
    Array.isArray(value.tool_results) &&
    value.tool_results.some(isValidDecodedToolResult);

  return hasThinking || hasResponse || hasToolCalls || hasToolResults;
}

export function decodedResponseText(decodedResponse) {
  if (!isDecodedResponse(decodedResponse)) {
    return null;
  }

  const keys = Object.keys(decodedResponse);
  if (keys.length === 1 && keys[0] === "response") {
    return decodedResponse.response;
  }

  return JSON.stringify(decodedResponse, null, 2);
}
