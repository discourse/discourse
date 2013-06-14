// moment.js language configuration
// language : norwegian bokmål (nb)
// author : Espen Hovlandsdal : https://github.com/rexxars

require('../moment').lang('nb', {
    months : "januar_februar_mars_april_mai_juni_juli_august_september_oktober_november_desember".split("_"),
    monthsShort : "jan_feb_mar_apr_mai_jun_jul_aug_sep_okt_nov_des".split("_"),
    weekdays : "søndag_mandag_tirsdag_onsdag_torsdag_fredag_lørdag".split("_"),
    weekdaysShort : "søn_man_tir_ons_tor_fre_lør".split("_"),
    weekdaysMin : "sø_ma_ti_on_to_fr_lø".split("_"),
    longDateFormat : {
        LT : "HH:mm",
        L : "YYYY-MM-DD",
        LL : "D MMMM YYYY",
        LLL : "D MMMM YYYY LT",
        LLLL : "dddd D MMMM YYYY LT"
    },
    calendar : {
        sameDay: '[I dag klokken] LT',
        nextDay: '[I morgen klokken] LT',
        nextWeek: 'dddd [klokken] LT',
        lastDay: '[I går klokken] LT',
        lastWeek: '[Forrige] dddd [klokken] LT',
        sameElse: 'L'
    },
    relativeTime : {
        future : "om %s",
        past : "for %s siden",
        s : "noen sekunder",
        m : "ett minutt",
        mm : "%d minutter",
        h : "en time",
        hh : "%d timer",
        d : "en dag",
        dd : "%d dager",
        M : "en måned",
        MM : "%d måneder",
        y : "ett år",
        yy : "%d år"
    },
    ordinal : '%d.',
    week : {
        dow : 1, // Monday is the first day of the week.
        doy : 4  // The week that contains Jan 4th is the first week of the year.
    }
});
