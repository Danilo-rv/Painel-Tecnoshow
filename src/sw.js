/* Guarda o app no aparelho para que o tablet abra o questionário mesmo sem internet.
   As respostas NÃO passam por aqui: ficam na fila do localStorage até a base confirmar. */
const CACHE = 'tsa-__VERSAO__';
const APP = ['./', 'index.html', 'vendor/d3.min.js', 'vendor/supabase.js', 'vendor/qrcode.js'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(APP)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('tsa-') && k !== CACHE).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  const req = e.request, url = new URL(req.url);
  if (req.method !== 'GET') return;
  const fonte = url.hostname === 'fonts.googleapis.com' || url.hostname === 'fonts.gstatic.com';
  if (url.origin !== location.origin && !fonte) return;      // nunca guarda chamadas ao Supabase
  if (fonte) {                                               // fontes: usa a cópia guardada e atualiza por trás
    e.respondWith(caches.open(CACHE).then(async c => {
      const hit = await c.match(req);
      const rede = fetch(req).then(r => { if (r.ok || r.type === 'opaque') c.put(req, r.clone()); return r; }).catch(() => hit);
      return hit || rede;
    }));
    return;
  }
  // app: tenta a rede primeiro (para receber atualizações) e cai na cópia guardada sem internet
  e.respondWith(fetch(req).then(r => {
    if (r.ok) { const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); }
    return r;
  }).catch(() => caches.match(req).then(h => h || caches.match('index.html'))));
});
