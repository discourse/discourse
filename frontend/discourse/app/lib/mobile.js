let mobileForced = false;

//  An object that is responsible for logic related to mobile devices.
const Mobile = {
  get mobileForced() {
    return mobileForced;
  },
};

export function forceMobile() {
  mobileForced = true;
}

export function resetMobile() {
  mobileForced = false;
}

export default Mobile;
