// moment.js language configuration
// language : ukrainian (uk)
// author : zemlanin : https://github.com/zemlanin

(function(){

var pluralRules = [
    function (n) { return ((n % 10 === 1) && (n % 100 !== 11)); },
    function (n) { return ((n % 10) >= 2 && (n % 10) <= 4 && ((n % 10) % 1) === 0) && ((n % 100) < 12 || (n % 100) > 14); },
    function (n) { return ((n % 10) === 0 || ((n % 10) >= 5 && (n % 10) <= 9 && ((n % 10) % 1) === 0) || ((n % 100) >= 11 && (n % 100) <= 14 && ((n % 100) % 1) === 0)); },
    function () { return true; }
];

function plural(word, num) {
    var forms = word.split('_'),
    minCount = Math.min(pluralRules.length, forms.length),
    i = -1;

    while (++i < minCount) {
        if (pluralRules[i](num)) {
            return forms[i];
        }
    }
    return forms[minCount - 1];
}

function relativeTimeWithPlural(number, withoutSuffix, key) {
    var format = {
        'mm': 'хвилина_хвилини_хвилин_хвилини',
        'hh': 'година_години_годин_години',
        'dd': 'день_дня_днів_дня',
        'MM': 'місяць_місяця_місяців_місяця',
        'yy': 'рік_року_років_року'
    };
    if (key === 'm') {
        return withoutSuffix ? 'хвилина' : 'хвилину';
    }
    else {
        return number + ' ' + plural(format[key], +number);
    }
}

function monthsCaseReplace(m, format) {
    var months = {
        'nominative': 'січень_лютий_березень_квітень_травень_червень_липень_серпень_вересень_жовтень_листопад_грудень'.split('_'),
        'accusative': 'січня_лютого_березня_квітня_травня_червня_липня_серпня_вересня_жовтня_листопада_грудня'.split('_')
    },

    nounCase = (/D[oD]? *MMMM?/).test(format) ?
        'accusative' :
        'nominative';

    return months[nounCase][m.month()];
}

function weekdaysCaseReplace(m, format) {
    var weekdays = {
        'nominative': 'неділя_понеділок_вівторок_середа_четвер_п’ятниця_субота'.split('_'),
        'accusative': 'неділю_понеділок_вівторок_середу_четвер_п’ятницю_суботу'.split('_')
    },

    nounCase = (/\[ ?[Вв] ?(?:попередню|наступну)? ?\] ?dddd/).test(format) ?
        'accusative' :
        'nominative';

    return weekdays[nounCase][m.day()];
}

moment.lang('uk', {
    months : monthsCaseReplace,
    monthsShort : "січ_лют_бер_кві_тра_чер_лип_сер_вер_жов_лис_гру".split("_"),
    weekdays : weekdaysCaseReplace,
    weekdaysShort : "нед_пон_вів_срд_чет_птн_суб".split("_"),
    weekdaysMin : "нд_пн_вт_ср_чт_пт_сб".split("_"),
    longDateFormat : {
        LT : "HH:mm",
        L : "DD.MM.YYYY",
        LL : "D MMMM YYYY г.",
        LLL : "D MMMM YYYY г., LT",
        LLLL : "dddd, D MMMM YYYY г., LT"
    },
    calendar : {
        sameDay: '[Сьогодні в] LT',
        nextDay: '[Завтра в] LT',
        lastDay: '[Вчора в] LT',
        nextWeek: function () {
            return this.day() === 2 ? '[У] dddd [в] LT' : '[В] dddd [в] LT';
        },
        lastWeek: function () {
            switch (this.day()) {
            case 0:
            case 3:
            case 5:
            case 6:
                return '[В минулу] dddd [в] LT';
            case 1:
            case 2:
            case 4:
                return '[В минулий] dddd [в] LT';
            }
        },
        sameElse: 'L'
    },
    // It needs checking (adding) ukrainan plurals and cases.
    relativeTime : {
        future : "через %s",
        past : "%s тому",
        s : "декілька секунд",
        m : relativeTimeWithPlural,
        mm : relativeTimeWithPlural,
        h : "годину",
        hh : relativeTimeWithPlural,
        d : "день",
        dd : relativeTimeWithPlural,
        M : "місяць",
        MM : relativeTimeWithPlural,
        y : "рік",
        yy : relativeTimeWithPlural
    },
    ordinal : '%d.',
    week : {
        dow : 1, // Monday is the first day of the week.
        doy : 7  // The week that contains Jan 1st is the first week of the year.
    }
});

})();
