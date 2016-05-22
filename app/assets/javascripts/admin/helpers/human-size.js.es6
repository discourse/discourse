import { htmlHelper } from 'discourse/lib/helpers';

export default htmlHelper(size => I18n.toHumanSize(size));
