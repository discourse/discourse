export default function createPopper(popper, reference, options = {}) {
  /* global Popper:true */
  return Popper.createPopper(popper, reference, options);
}
