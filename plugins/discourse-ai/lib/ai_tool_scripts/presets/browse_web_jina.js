let url;
function invoke(p) {
  url = p.url;
  const result = http.get(`https://r.jina.ai/${url}`);
  // truncates to 15000 tokens
  return llm.truncate(result.body, 15000);
}
function details() {
  return "Read: " + url;
}
