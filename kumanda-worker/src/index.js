// TV İzle hesapsız kumanda köprüsü — yalnızca API (telefon arayüzü TV İzle dosyasının içinde)
// Her eşleştirme kodu bir Room (Durable Object) üretir. TV gizli anahtarla komut çeker
// ve durum yazar; telefon yalnızca kodla komut gönderir ve durumu okur.

const JSON_HDR = { 'content-type': 'application/json; charset=utf-8' };
const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'POST, GET, OPTIONS',
  'access-control-allow-headers': 'content-type',
};
const ALPH = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const TV_TTL_MS = 120000;        // TV bu süre komut çekmezse "çevrim dışı"
const ROOM_KEEP_MS = 30 * 60000; // TV tamamen kapanırsa oda 30 dk sonra silinir
const PHONE_ACTIONS = new Set(['ch+', 'ch-', 'play', 'mute', 'vol+', 'vol-', 'seek', 'list',
  'play-idx', 'pl-idx', 'play-no', 'play-fav', 'cat-idx', 'cat+', 'cat-', 'vq', 'pl-add', 'pl-del', 'key']);

function jres(obj, status = 200) {
  return new Response(JSON.stringify(obj), { status, headers: { ...JSON_HDR, ...CORS } });
}
function randCode() {
  const a = new Uint32Array(6); crypto.getRandomValues(a);
  let s = ''; for (const x of a) s += ALPH[x % ALPH.length]; return s;
}
function randHex(n) {
  const a = new Uint8Array(n); crypto.getRandomValues(a);
  return [...a].map(b => b.toString(16).padStart(2, '0')).join('');
}

export class Room {
  constructor(state) { this.state = state; }

  async fetch(req) {
    try { return await this.handle(req); }
    catch (e) { return jres({ ok: false, error: 'ROOM_ERROR', detail: String(e && e.message || e) }, 500); }
  }

  async handle(req) {
    const body = await req.json();
    const op = body.op;
    const st = this.state.storage;

    if (op === 'init') {
      if (await st.get('secret')) return jres({ ok: false, error: 'EXISTS' }, 409);
      await st.put({ secret: body.secret, tvSeen: Date.now(), cmds: [], state: {} });
      return jres({ ok: true });
    }

    const secret = await st.get('secret');
    if (!secret) return jres({ ok: false, error: 'NOT_FOUND' }, 404);

    if (op === 'poll' || op === 'event') {
      if (body.secret !== secret) return jres({ ok: false, error: 'BAD_SECRET' }, 403);
      await st.put('tvSeen', Date.now());
      await st.setAlarm(Date.now() + ROOM_KEEP_MS);
    } else {
      const seen = (await st.get('tvSeen')) || 0;
      if (Date.now() - seen > TV_TTL_MS) return jres({ ok: false, error: 'TV_OFFLINE' }, 503);
    }

    switch (op) {
      case 'poll': {
        const cmds = (await st.get('cmds')) || [];
        if (cmds.length) await st.put('cmds', []);
        return jres({ ok: true, cmds });
      }
      case 'event': {
        const type = body.type, data = body.data;
        const cur = (await st.get('state')) || {};
        if (type === 'state' && data && typeof data === 'object') {
          await st.put('state', Object.assign(cur, data));
        } else if (type === 'list' && data) {
          await st.put('list', {
            names: String(data.names || '').slice(0, 120000), n: data.n | 0,
            nos: String(data.nos || '').slice(0, 40000), cg: String(data.cg || '').slice(0, 40000),
            cats: String(data.cats || '').slice(0, 4000), cs: String(data.cs || '').slice(0, 60000),
            ca: data.ca | 0, at: Date.now(),
          });
        } else if (type === 'vres' && data) {
          let s = ''; try { s = JSON.stringify(data); } catch (e) {}
          if (s && s.length <= 100000) await st.put('vres', { k: String(data.k || '').slice(0, 64), d: s, at: Date.now() });
        } else if (type === 'ack' && data) {
          cur.rx = { a: data.a || '', st: data.ok ? 'ok' : (data.why || 'fail'), at: Date.now() };
          await st.put('state', cur);
        } else if (type === 'err') {
          cur.err = String(data || '').slice(0, 100);
          await st.put('state', cur);
        } else if (type === 'file' && data) {
          const key = 'file:' + String(Date.now()).padStart(15, '0');
          await st.put(key, { name: String(data.name || '').slice(0, 80), text: String(data.text || '').slice(0, 100000), at: Date.now() });
          const old = await st.list({ prefix: 'file:' });
          const keys = [...old.keys()];
          if (keys.length > 10) await st.delete(keys.slice(0, keys.length - 10));
        }
        return jres({ ok: true });
      }
      case 'get': {
        const what = body.what;
        if (what === 'state') return jres({ ok: true, data: (await st.get('state')) || {} });
        if (what === 'list') return jres({ ok: true, data: (await st.get('list')) || null });
        if (what === 'vres') return jres({ ok: true, data: (await st.get('vres')) || null });
        if (what === 'files') {
          const m = await st.list({ prefix: 'file:', reverse: true, limit: 10 });
          return jres({ ok: true, data: [...m.values()] });
        }
        return jres({ ok: false, error: 'BAD_WHAT' }, 400);
      }
      case 'cmd': {
        const c = body.cmd || {};
        if (!PHONE_ACTIONS.has(c.a)) return jres({ ok: false, error: 'BAD_ACTION' }, 400);
        const cmd = { a: c.a, k: randHex(6), ts: Date.now() };
        if (c.i !== undefined) cmd.i = c.i | 0;
        if (c.v !== undefined) cmd.v = Number(c.v) || 0;
        if (c.n !== undefined) cmd.n = String(c.n).slice(0, 100);
        if (c.t !== undefined) cmd.t = String(c.t).slice(0, 20);
        if (c.d !== undefined) cmd.d = String(c.d).slice(0, 10); // D-pad yönü: up|down|left|right|ok|back
        if (c.q !== undefined) cmd.q = String(c.q).slice(0, 80);
        if (c.g !== undefined) cmd.g = String(c.g).slice(0, 80);
        if (c.url !== undefined) cmd.url = String(c.url).slice(0, 500);
        const cmds = (await st.get('cmds')) || [];
        if (cmds.length >= 50) return jres({ ok: false, error: 'QUEUE_FULL' }, 429);
        cmds.push(cmd);
        await st.put('cmds', cmds);
        return jres({ ok: true, k: cmd.k });
      }
      default:
        return jres({ ok: false, error: 'BAD_OP' }, 400);
    }
  }

  async alarm() { await this.state.storage.deleteAll(); }
}

export default {
  async fetch(req, env) {
    try { return await route(req, env); }
    catch (e) { return jres({ ok: false, error: 'WORKER_ERROR', detail: String(e && e.message || e) }, 500); }
  },
};

async function route(req, env) {
    const url = new URL(req.url);
    if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });
    if (url.pathname === '/api/health') return jres({ ok: true, v: 2 });
    if (!env.ROOM) return jres({ ok: false, error: 'ROOM_BINDING_MISSING', detail: 'ROOM yok. Görülen bindingler: [' + Object.keys(env).join(', ') + ']' }, 500);

    if (url.pathname === '/api/new' && req.method === 'POST') {
      for (let t = 0; t < 5; t++) {
        const code = randCode(), secret = randHex(24);
        const stub = env.ROOM.get(env.ROOM.idFromName(code));
        const r = await stub.fetch('https://room/op', { method: 'POST', body: JSON.stringify({ op: 'init', secret }) });
        if (r.status === 200) return jres({ ok: true, code, secret });
      }
      return jres({ ok: false, error: 'BUSY' }, 503);
    }

    const m = url.pathname.match(/^\/api\/(tv|phone)\/(poll|event|get|cmd)$/);
    if (m && req.method === 'POST') {
      const allowed = m[1] === 'tv' ? ['poll', 'event'] : ['get', 'cmd'];
      if (!allowed.includes(m[2])) return jres({ ok: false, error: 'NOT_FOUND' }, 404);
      let body;
      try { body = await req.json(); } catch (e) { return jres({ ok: false, error: 'BAD_JSON' }, 400); }
      const code = String(body.code || '').toUpperCase().replace(/[^A-Z0-9]/g, '');
      if (code.length !== 6) return jres({ ok: false, error: 'BAD_CODE' }, 400);
      const stub = env.ROOM.get(env.ROOM.idFromName(code));
      const r = await stub.fetch('https://room/op', { method: 'POST', body: JSON.stringify({ ...body, op: m[2] }) });
      return new Response(r.body, { status: r.status, headers: { ...JSON_HDR, ...CORS } });
    }

    return jres({ ok: false, error: 'NOT_FOUND' }, 404);
}
