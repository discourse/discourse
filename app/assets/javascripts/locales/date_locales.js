// fix DE locale
Date.getLocale('de').short_no_year = '{d}. {month}';

// fix EN locale
Date.getLocale('en').short_no_year = '{d} {Mon}';

// fix FR locale
Date.getLocale('fr').short_no_year = '{d} {month}';

// fix NL locale
Date.getLocale('nl').short_no_year = '{d} {Month}';

// fix SV locale
Date.getLocale('sv').short_no_year = 'den {d} {month}';

// fix zh_CN locale
Date.getLocale('zh-CN').short_no_year = '{yyyy}年{M}月';

// create CS locale, because it's not supported by Sugar at all
Date.addLocale('cs', {
    'plural': true,
    'capitalizeUnit': false,
    'months': 'ledna,února,března,dubna,května,června,července,srpna,září,října,listopadu,prosince',
    'weekdays': 'neděle,pondělí,úterý,středa,čtvrtek,pátek,sobota',
    'units': 'milisekund:a|y||ou|ami,sekund:a|y||ou|ami,minut:a|y||ou|ami,hodin:a|y||ou|ami,den|dny|dnů|dnem|dny,týden|týdny|týdnů|týdnem|týdny,měsíc:|e|ů|em|emi,rok|roky|let|rokem|lety',
    'short': '{d}. {month} {yyyy}',
    'short_no_year': '{d}. {month}',
    'long': '{d}. {month} {yyyy} {H}:{mm}',
    'full': '{weekday} {d}. {month} {yyyy} {H}:{mm}:{ss}',
    'relative': function(num, unit, ms, format) {
        var numberWithUnit, last = num.toString().slice(-1);
        var mult;
        if (format === 'past' || format === 'future') {
            if (num === 1) mult = 3;
            else mult = 4;
        } else {
            if (num === 1) mult = 0;
            else if (num >= 2 && num <= 4) mult = 1;
            else mult = 2;
        }
        numberWithUnit = num + ' ' + this.units[(mult * 8) + unit];
        switch(format) {
            case 'duration':  return numberWithUnit;
            case 'past':      return 'před ' + numberWithUnit;
            case 'future':    return 'za ' + numberWithUnit;
        }
    }
});

// set the current date locale, replace underscore with dash to make zh_CN work
Date.setLocale(I18n.locale.replace("_","-"));
