import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';

export default createWidget('secondary-title', {
    tagName: 'div.secondary-title',
    buildKey: () => 'secondary-title',

    html(attrs, state) {
        console.log("test");
        var url = window.location.href;
        var parser = document.createElement('a');
        parser.href = url;
        var pathname = parser.pathname;
        var stitle = 'Forums Home';
        if(pathname.indexOf('/c/') === 0 && pathname.length > 3){
            stitle = pathname.substring(3);
            if(stitle.indexOf('/') !== -1)
                stitle = stitle.substring(0, stitle.indexOf('/'));
        }
        stitle = stitle.replace('-', ' ');
        return h('span.greeting', stitle.toUpperCase());
    },

});
