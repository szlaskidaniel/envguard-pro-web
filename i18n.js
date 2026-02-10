(function () {
  'use strict';

  var SUPPORTED = ['en', 'pl'];
  var DEFAULT = 'en';
  var KEY = 'envguard-lang';

  // Detect current page name for page-specific translation keys
  var page = (function () {
    var p = window.location.pathname;
    if (p.indexOf('installation') !== -1) return 'installation';
    if (p.indexOf('privacy') !== -1) return 'privacy';
    if (p.indexOf('terms') !== -1) return 'terms';
    return 'index';
  })();

  // Determine language: localStorage > browser > default
  function getLang() {
    var stored = localStorage.getItem(KEY);
    if (stored && SUPPORTED.indexOf(stored) !== -1) return stored;
    var nav = (navigator.language || navigator.userLanguage || '').toLowerCase();
    for (var i = 0; i < SUPPORTED.length; i++) {
      if (nav.indexOf(SUPPORTED[i]) === 0) return SUPPORTED[i];
    }
    return DEFAULT;
  }

  var currentLang = getLang();

  // Resolve dotted path like "common.nav_features" from nested object
  function resolve(obj, path) {
    var parts = path.split('.');
    var cur = obj;
    for (var i = 0; i < parts.length; i++) {
      if (cur == null) return undefined;
      cur = cur[parts[i]];
    }
    return cur;
  }

  // Determine base path to i18n/ directory relative to current page
  function basePath() {
    // All pages are at root; ads in marketing/ads/ are skipped
    var p = window.location.pathname;
    if (p.indexOf('marketing/') !== -1) return '../../';
    return '';
  }

  function applyTranslations(t, lang) {
    // Update <html lang>
    document.documentElement.lang = lang;

    // Update <title>
    var title = resolve(t, page + '.page_title');
    if (title) document.title = title;

    // Update <meta name="description">
    var desc = resolve(t, page + '.meta_description');
    if (desc) {
      var meta = document.querySelector('meta[name="description"]');
      if (meta) meta.setAttribute('content', desc);
    }

    // data-i18n → textContent
    var els = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < els.length; i++) {
      var val = resolve(t, els[i].getAttribute('data-i18n'));
      if (val !== undefined) els[i].textContent = val;
    }

    // data-i18n-html → innerHTML
    var htmlEls = document.querySelectorAll('[data-i18n-html]');
    for (var j = 0; j < htmlEls.length; j++) {
      var hVal = resolve(t, htmlEls[j].getAttribute('data-i18n-html'));
      if (hVal !== undefined) htmlEls[j].innerHTML = hVal;
    }

    // data-i18n-attr → setAttribute  (format: "attr1:key1;attr2:key2")
    var attrEls = document.querySelectorAll('[data-i18n-attr]');
    for (var k = 0; k < attrEls.length; k++) {
      var pairs = attrEls[k].getAttribute('data-i18n-attr').split(';');
      for (var l = 0; l < pairs.length; l++) {
        var parts = pairs[l].split(':');
        if (parts.length === 2) {
          var aVal = resolve(t, parts[1].trim());
          if (aVal !== undefined) attrEls[k].setAttribute(parts[0].trim(), aVal);
        }
      }
    }

    // Remove loading state, show body
    document.documentElement.classList.remove('i18n-loading');
    document.documentElement.classList.add('i18n-ready');
  }

  function loadAndApply(lang) {
    var url = basePath() + 'i18n/' + lang + '.json';
    fetch(url)
      .then(function (r) { return r.json(); })
      .then(function (t) { applyTranslations(t, lang); })
      .catch(function (e) {
        console.warn('[i18n] Failed to load ' + lang, e);
        // Still show the page even if loading fails
        document.documentElement.classList.remove('i18n-loading');
        document.documentElement.classList.add('i18n-ready');
      });
  }

  // Language switcher
  function initSwitcher(lang) {
    var btn = document.getElementById('langSwitch');
    if (!btn) return;

    function updateUI(active) {
      btn.innerHTML =
        '<span' + (active === 'en' ? ' class="active-lang"' : '') + '>EN</span>' +
        ' | ' +
        '<span' + (active === 'pl' ? ' class="active-lang"' : '') + '>PL</span>';
      btn.title = active === 'en' ? 'Przełącz na polski' : 'Switch to English';
    }

    updateUI(lang);

    btn.addEventListener('click', function () {
      var next = lang === 'en' ? 'pl' : 'en';
      localStorage.setItem(KEY, next);
      lang = next;

      if (next === DEFAULT) {
        // English is baked into HTML — just reload
        window.location.reload();
      } else {
        loadAndApply(next);
        updateUI(next);
      }
    });
  }

  // Boot
  if (currentLang !== DEFAULT) {
    loadAndApply(currentLang);
  } else {
    // English: page is already correct, just reveal
    document.documentElement.classList.remove('i18n-loading');
    document.documentElement.classList.add('i18n-ready');
  }

  initSwitcher(currentLang);
})();
