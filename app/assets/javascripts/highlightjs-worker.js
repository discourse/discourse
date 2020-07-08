// Standalone worker for highlightjs syntax generation

// The highlightjs path changes based on site settings,
// so we wait for Discourse to pass the path into the worker
const loadHighlightJs = path => {
  self.importScripts(path);
};

const highlight = ({ id, text, language }) => {
  if (!self.hljs) {
    throw "HighlightJS is not loaded";
  }

  const result = language
    ? self.hljs.highlight(language, text, true).value
    : self.hljs.highlightAuto(text).value;

  postMessage({
    type: "highlightResult",
    id: id,
    result: result
  });
};

const registerLanguage = ({ name, definition }) => {
  if (!self.hljs) {
    throw "HighlightJS is not loaded";
  }
  self.hljs.registerLanguage(name, () => {
    return definition;
  });
};

onmessage = event => {
  const data = event.data;
  const messageType = data.type;

  if (messageType === "loadHighlightJs") {
    loadHighlightJs(data.path);
  } else if (messageType === "registerLanguage") {
    registerLanguage(data);
  } else if (messageType === "highlight") {
    highlight(data);
  } else {
    throw `Unknown message type: ${messageType}`;
  }
};
