import ScrollTop from 'discourse/mixins/scroll-top';
import { createViewWithBodyClass } from 'discourse/lib/create-view';

export default createViewWithBodyClass('badges-page').extend(ScrollTop);
