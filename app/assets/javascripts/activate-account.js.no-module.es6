(function() {
  setTimeout(function() {
    const $activateButton = $("#activate-account-button");
    $activateButton.on("click", function() {
      $activateButton.prop("disabled", true);
      const hpPath = document.getElementById("data-activate-account").dataset
        .path;
      $.ajax(hpPath)
        .then(function(hp) {
          $("#password_confirmation").val(hp.value);
          $("#challenge").val(
            hp.challenge
              .split("")
              .reverse()
              .join("")
          );
          $("#activate-account-form").submit();
        })
        .fail(function() {
          $activateButton.prop("disabled", false);
        });
    });
  }, 50);
})();
