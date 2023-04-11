export default function setHeaderOffset(value) {
  return new Promise((resolve) => {
    document.documentElement.style.setProperty("--header-offset", value);
    setTimeout(() => {
      resolve();
    }, 200);
  });
}
