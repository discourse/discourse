(function() {
  const { authResult, baseUrl } = document.getElementById(
    "data-auth-result"
  ).dataset;
  const parsedAuthResult = JSON.parse(authResult);

  if (!window.opener) {
    localStorage.setItem("lastAuthResult", authResult);
    window.location.href = `${baseUrl}?authComplete=true`;
  } else {
    window.opener.Discourse.authenticationComplete(parsedAuthResult);
    window.close();
  }
})();
