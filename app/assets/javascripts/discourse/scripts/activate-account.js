(function () {
  const activateButton = document.querySelector("#activate-account-button");
  activateButton.addEventListener("click", async function () {
    activateButton.setAttribute("disabled", true);
    const hpPath = document.getElementById("data-activate-account").dataset
      .path;

    try {
      const response = await fetch(hpPath, {
        headers: {
          Accept: "application/json",
        },
      });
      const hp = await response.json();

      document.querySelector("#password_confirmation").value = hp.value;
      document.querySelector("#challenge").value = hp.challenge
        .split("")
        .reverse()
        .join("");
      document.querySelector("#activate-account-form").submit();
    } catch (e) {
      activateButton.removeAttribute("disabled");
      throw e;
    }
  });
})();
