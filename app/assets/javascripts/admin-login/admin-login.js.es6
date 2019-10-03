import { getWebauthnCredential } from "discourse/lib/webauthn";

export default function() {
  document.getElementById(
    "activate-security-key-alternative"
  ).onclick = function() {
    document.getElementById("second-factor-forms").style.display = "block";
    document.getElementById("primary-security-key-form").style.display = "none";
  };

  document.getElementById("submit-security-key").onclick = function(e) {
    e.preventDefault();
    getWebauthnCredential(
      document.getElementById("security-key-challenge").value,
      document
        .getElementById("security-key-allowed-credential-ids")
        .value.split(","),
      credentialData => {
        document.getElementById(
          "security-key-credential"
        ).value = JSON.stringify(credentialData);
        e.target.parentElement.submit();
      },
      errorMessage => {
        document.getElementById("security-key-error").innerText = errorMessage;
      }
    );
  };

  const useTotp = I18n.t("login.second_factor_toggle.totp");
  const useBackup = I18n.t("login.second_factor_toggle.backup_code");
  const backupForm = document.getElementById("backup-second-factor-form");
  const primaryForm = document.getElementById("primary-second-factor-form");
  document.getElementById("toggle-form").onclick = function(event) {
    event.preventDefault();
    if (backupForm.style.display === "none") {
      backupForm.style.display = "block";
      primaryForm.style.display = "none";
      document.getElementById("toggle-form").innerHTML = useTotp;
    } else {
      backupForm.style.display = "none";
      primaryForm.style.display = "block";
      document.getElementById("toggle-form").innerHTML = useBackup;
    }
  };
}
