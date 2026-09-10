import { registerDestructor } from "@ember/destroyable";

export const customPopupMenuOptions = [];
const optionRegistrations = [];

export function clearPopupMenuOptions() {
  customPopupMenuOptions.length = 0;
  optionRegistrations.length = 0;
}

export function addPopupMenuOption(option, { owner } = {}) {
  const registration = {};
  optionRegistrations.push(registration);
  customPopupMenuOptions.push(option);

  if (owner) {
    registerDestructor(owner, () => {
      const index = optionRegistrations.indexOf(registration);
      if (index !== -1) {
        optionRegistrations.splice(index, 1);
        customPopupMenuOptions.splice(index, 1);
      }
    });
  }
}
