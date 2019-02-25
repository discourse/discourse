(function() {
  const path = document.getElementById("data-auto-redirect").dataset.path;
  setTimeout(function() {
    window.location.href = path;
  }, 2000);
})();
