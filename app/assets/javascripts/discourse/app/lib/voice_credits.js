/* eslint-disable no-alert */
/* eslint-disable no-console */

function isValidAllocation(voiceCreditsData) {
  const totalCredits = voiceCreditsData.reduce(
    (sum, { credits_allocated }) => sum + parseInt(credits_allocated, 10),
    0
  );
  return totalCredits <= 100;
}

document.addEventListener("DOMContentLoaded", () => {
  const voiceCreditsInputs = document.querySelectorAll(".voice-credits-input");
  const saveButton = document.getElementById("save-voice-credits");

  saveButton.addEventListener("click", () => {
    const voiceCreditsData = Array.from(voiceCreditsInputs).map((input) => {
      return {
        topic_id: input.dataset.topicId,
        credits_allocated: input.value,
      };
    });

    if (!isValidAllocation(voiceCreditsData)) {
      alert(
        "You have exceeded the maximum allocation of 100 credits. Please adjust your allocations and try again."
      );
      return;
    }

    fetch("/voice_credits", {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.getElementsByName("csrf-token")[0].content,
      },
      body: JSON.stringify({ voice_credits: voiceCreditsData }),
    })
      .then((response) => response.json())
      .then((data) => {
        if (data.success) {
          alert("Voice credits saved successfully!");
          location.reload();
        } else {
          alert(
            "There was an error saving your voice credits. Please try again."
          );
        }
      })
      .catch((error) => {
        console.error("Error:", error);
        alert(
          "There was an error saving your voice credits. Please try again."
        );
      });
  });
});
