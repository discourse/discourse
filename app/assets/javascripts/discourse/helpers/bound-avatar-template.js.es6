import { htmlHelper } from 'discourse/lib/helpers';

export default htmlHelper((avatarTemplate, size) => {
  return Discourse.Utilities.avatarImg({ size, avatarTemplate });
});
