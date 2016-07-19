import { htmlHelper } from 'discourse/lib/helpers';
import { avatarImg } from 'discourse/lib/utilities';

export default htmlHelper((avatarTemplate, size) => avatarImg({ size, avatarTemplate }));
