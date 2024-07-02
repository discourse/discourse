/**
 * Represent a date as a short/default/long/full string
 *
 * @param value Either a Unix epoch time in milliseconds, or a string value
 *   representing a date. Parsed with `new Date(value)`
 *
 * @example
 * ```js
 * var mf = new MessageFormat(['en', 'fi']);
 *
 * mf.compile('Today is {T, date}')({ T: Date.now() })
 * // 'Today is Feb 21, 2016'
 *
 * mf.compile('Tänään on {T, date}', 'fi')({ T: Date.now() })
 * // 'Tänään on 21. helmikuuta 2016'
 *
 * mf.compile('Unix time started on {T, date, full}')({ T: 0 })
 * // 'Unix time started on Thursday, January 1, 1970'
 *
 * var cf = mf.compile('{sys} became operational on {d0, date, short}');
 * cf({ sys: 'HAL 9000', d0: '12 January 1999' })
 * // 'HAL 9000 became operational on 1/12/1999'
 * ```
 */
function date(r,n,t){var e={day:"numeric",month:"short",year:"numeric"};switch(t){case"full":e.weekday="long";case"long":e.month="long";break;case"short":e.month="numeric"}return new Date(r).toLocaleDateString(n,e)}
/**
 * Represent a duration in seconds as a string
 *
 * @param value A finite number, or its string representation
 * @return Includes one or two `:` separators, and matches the pattern
 *   `hhhh:mm:ss`, possibly with a leading `-` for negative values and a
 *   trailing `.sss` part for non-integer input
 *
 * @example
 * ```js
 * var mf = new MessageFormat();
 *
 * mf.compile('It has been {D, duration}')({ D: 123 })
 * // 'It has been 2:03'
 *
 * mf.compile('Countdown: {D, duration}')({ D: -151200.42 })
 * // 'Countdown: -42:00:00.420'
 * ```
 */function duration(r){"number"!==typeof r&&(r=Number(r));if(!isFinite(r))return String(r);var n="";if(r<0){n="-";r=Math.abs(r)}else r=Number(r);var t=r%60;var e=[Math.round(t)===t?t:t.toFixed(3)];if(r<60)e.unshift(0);else{r=Math.round((r-Number(e[0]))/60);e.unshift(r%60);if(r>=60){r=Math.round((r-Number(e[0]))/60);e.unshift(r)}}var i=e.shift();return n+i+":"+e.map((function(r){return r<10?"0"+String(r):String(r)})).join(":")}var r={};function nf(n,t){var e=String(n)+JSON.stringify(t);r[e]||(r[e]=new Intl.NumberFormat(n,t));return r[e]}function numberFmt(r,n,t,e){var i=t&&t.split(":")||[],u=i[0],a=i[1];var m={integer:{maximumFractionDigits:0},percent:{style:"percent"},currency:{style:"currency",currency:a&&a.trim()||e,minimumFractionDigits:2,maximumFractionDigits:2}};return nf(n,m[u]||{}).format(r)}var numberCurrency=function(r,n,t){return nf(n,{style:"currency",currency:t,minimumFractionDigits:2,maximumFractionDigits:2}).format(r)};var numberInteger=function(r,n){return nf(n,{maximumFractionDigits:0}).format(r)};var numberPercent=function(r,n){return nf(n,{style:"percent"}).format(r)};
/**
 * Represent a time as a short/default/long string
 *
 * @param value Either a Unix epoch time in milliseconds, or a string value
 *   representing a date. Parsed with `new Date(value)`
 *
 * @example
 * ```js
 * var mf = new MessageFormat(['en', 'fi']);
 *
 * mf.compile('The time is now {T, time}')({ T: Date.now() })
 * // 'The time is now 11:26:35 PM'
 *
 * mf.compile('Kello on nyt {T, time}', 'fi')({ T: Date.now() })
 * // 'Kello on nyt 23.26.35'
 *
 * var cf = mf.compile('The Eagle landed at {T, time, full} on {T, date, full}');
 * cf({ T: '1969-07-20 20:17:40 UTC' })
 * // 'The Eagle landed at 10:17:40 PM GMT+2 on Sunday, July 20, 1969'
 * ```
 */function time(r,n,t){var e={second:"numeric",minute:"numeric",hour:"numeric"};switch(t){case"full":case"long":e.timeZoneName="short";break;case"short":delete e.second}return new Date(r).toLocaleTimeString(n,e)}export{date,duration,numberCurrency,numberFmt,numberInteger,numberPercent,time};

