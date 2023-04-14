/* eslint-disable no-alert */
/* eslint-disable no-console */

document.addEventListener("DOMContentLoaded", () => {
  const voiceCreditsInputs = document.querySelectorAll(".voice-credits-input");
  const saveButton = document.getElementById("save-voice-credits");
  let voiceCredits = {};
  // Add event listeners to handle user input changes on the voice credit input elements
  voiceCreditsInputs.forEach((input) => {
    input.addEventListener("input", (event) => {
      console.log("input event", event);
      const topicId = parseInt(input.dataset.topicId, 10);
      voiceCredits[topicId] = parseInt(event.target.value, 10);
    });
  });
  saveButton.addEventListener("click", () => {
    console.log("voiceCredits", voiceCredits);
    // Validate if the total allocated credits are within the limit (100)
    const totalCredits = Object.values(voiceCredits).reduce(
      (sum, credits) => sum + credits,
      0
    );
    if (totalCredits > 100) {
      alert(
        "You have allocated more than 100 voice credits. Please adjust your allocations."
      );
      return;
    }
  });
});
