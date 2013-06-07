// moment.js language configuration
// language : Hebrew (he)
// author : Tomer Cohen : https://github.com/tomer
// author : Moshe Simantov : https://github.com/DevelopmentIL

require('../moment').lang('he', {
    months : "ינואר_פברואר_מרץ_אפריל_מאי_יוני_יולי_אוגוסט_ספטמבר_אוקטובר_נובמבר_דצמבר".split("_"),
    monthsShort : "ינו׳_פבר׳_מרץ_אפר׳_מאי_יוני_יולי_אוג׳_ספט׳_אוק׳_נוב׳_דצמ׳".split("_"),
    weekdays : "ראשון_שני_שלישי_רביעי_חמישי_שישי_שבת".split("_"),
    weekdaysShort : "א׳_ב׳_ג׳_ד׳_ה׳_ו׳_ש׳".split("_"),
    weekdaysMin : "א_ב_ג_ד_ה_ו_ש".split("_"),
    longDateFormat : {
        LT : "HH:mm",
        L : "DD/MM/YYYY",
        LL : "D [ב]MMMM YYYY",
        LLL : "D [ב]MMMM YYYY LT",
        LLLL : "dddd, D [ב]MMMM YYYY LT",
        l : "D/M/YYYY",
        ll : "D MMM YYYY",
        lll : "D MMM YYYY LT",
        llll : "ddd, D MMM YYYY LT"
    },
    calendar : {
        sameDay : '[היום ב־]LT',
        nextDay : '[מחר ב־]LT',
        nextWeek : 'dddd [בשעה] LT',
        lastDay : '[אתמול ב־]LT',
        lastWeek : '[ביום] dddd [האחרון בשעה] LT',
        sameElse : 'L'
    },
    relativeTime : {
        future : "בעוד %s",
        past : "לפני %s",
        s : "מספר שניות",
        m : "דקה",
        mm : "%d דקות",
        h : "שעה",
        hh : "%d שעות",
        d : "יום",
        dd : "%d ימים",
        M : "חודש",
        MM : "%d חודשים",
        y : "שנה",
        yy : "%d שנים"
    }
});
