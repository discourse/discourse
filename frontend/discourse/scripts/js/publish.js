(function () {
  window.onload = function () {
    // Use a # for hashtags since we don't have the JS and icons needed here to render the proper icon.
    let hashtags = document.querySelectorAll(
      ".published-page-content-body a.hashtag-cooked"
    );
    for (let i = 0; i < hashtags.length; i++) {
      hashtags[i].querySelector(".hashtag-icon-placeholder .d-icon").remove();
      hashtags[i].querySelector(".hashtag-icon-placeholder").innerText = "#";
    }
  };
})();
