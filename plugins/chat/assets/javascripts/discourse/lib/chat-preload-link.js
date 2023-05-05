export function addPreloadLink(url, id) {
  if (document.querySelector(`link[href="${url}"][rel="preload"]`)) {
    return;
  }

  const importNode = document.createElement("link");
  importNode.id = id;
  importNode.rel = "preload";
  importNode.crossOrigin = "anonymous";
  importNode.as = "fetch";
  importNode.href = url;
  importNode.onload = () => {
    importNode?.classList?.add("is-preloaded");
  };

  document.head.appendChild(importNode);
}
