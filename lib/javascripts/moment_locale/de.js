// moment.js language configuration
// language : german (de)
// author : lluchs : https://github.com/lluchs

(function(){
moment.lang('de', {
    months : "Januar_Februar_März_April_Mai_Juni_Juli_August_September_Oktober_November_Dezember".split("_"),
    monthsShort : "Jan._Febr._Mrz._Apr._Mai_Jun._Jul._Aug._Sept._Okt._Nov._Dez.".split("_"),
    weekdays : "Sonntag_Montag_Dienstag_Mittwoch_Donnerstag_Freitag_Samstag".split("_"),
    weekdaysShort : "So._Mo._Di._Mi._Do._Fr._Sa.".split("_"),
    weekdaysMin : "So_Mo_Di_Mi_Do_Fr_Sa".split("_"),
    longDateFormat : {
        LT: "H:mm [Uhr]",
        L : "DD.MM.YYYY",
        LL : "D. MMMM YYYY",
        LLL : "D. MMMM YYYY LT",
        LLLL : "dddd, D. MMMM YYYY LT"
    },
    calendar : {
        sameDay: "[Heute um] LT",
        sameElse: "L",
        nextDay: '[Morgen um] LT',
        nextWeek: 'dddd [um] LT',
        lastDay: '[Gestern um] LT',
        lastWeek: '[letzten] dddd [um] LT'
    },
    relativeTime : {
        future : "in %s",
        past : "vor %s",
        s : "ein paar Sekunden",
        m : "einer Minute",
        mm : "%d Minuten",
        h : "einer Stunde",
        hh : "%d Stunden",
        d : "einem Tag",
        dd : "%d Tagen",
        M : "einem Monat",
        MM : "%d Monaten",
        y : "einem Jahr",
        yy : "%d Jahren"
    },
    ordinal : '%d.',
    week : {
        dow : 1, // Monday is the first day of the week.
        doy : 4  // The week that contains Jan 4th is the first week of the year.
    }
});

})();
