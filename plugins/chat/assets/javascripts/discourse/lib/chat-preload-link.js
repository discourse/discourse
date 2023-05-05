export function addPreloadLink(url) {
  if (document.querySelector(`link[href="${url}"][rel="preload"]`)) {
    return;
  }

  const importNode = document.createElement("link");
  importNode.rel = "preload";
  importNode.crossOrigin = "anonymous";
  importNode.as = "fetch";
  importNode.href = url;
  importNode.onload = () => {
    importNode?.classList?.add("is-prefetched");
  };

  document.head.appendChild(importNode);
}
