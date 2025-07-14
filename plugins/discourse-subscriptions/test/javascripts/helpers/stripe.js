import { Promise } from "rsvp";

export function stubStripe() {
  window.Stripe = () => {
    return {
      createPaymentMethod() {
        return new Promise((resolve) => {
          resolve({});
        });
      },
      elements() {
        return {
          create() {
            return {
              on() {},
              card() {},
              mount() {},
              update() {},
            };
          },
        };
      },
    };
  };
}
