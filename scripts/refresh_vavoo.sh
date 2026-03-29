#!/bin/bash
mkdir -p playlist
echo "#EXTM3U" > playlist/vavoo_playlist.m3u

echo ">>> Vavoo auth token alınıyor..."
SIG=$(python3 -c "
import asyncio, hashlib, time, socket
from aiohttp import ClientSession, ClientTimeout, TCPConnector

_LOKKE_PING_URL = 'https://www.lokke.app/api/app/ping'
_LOKKE_TOKEN = 'ldCvE092e7gER0rVIajfsXIvRhwlrAzP6_1oEJ4q6HH89QHt24v6NNL_jQJO219hiLOXF2hqEfsUuEWitEIGN4EaHHEHb7Cd7gojc5SQYRFzU3XWo_kMeryAUbcwWnQrnf0-'

async def get_sig():
    uid = hashlib.md5(str(time.time()).encode()).hexdigest()[:16]
    now = int(time.time()*1000)
    body = {'token':_LOKKE_TOKEN,'reason':'app-blur','locale':'de','theme':'dark',
        'metadata':{'device':{'type':'Handset','brand':'google','model':'Nexus','name':'21081111RG','uniqueId':uid},
        'os':{'name':'android','version':'7.1.2','abis':['arm64-v8a'],'host':'android'},
        'app':{'platform':'android','version':'1.1.0','buildId':'97215000','engine':'hbc85',
            'signatures':['6e8a975e3cbf07d5de823a760d4c2547f86c1403105020adee5de67ac510999e'],
            'installer':'com.android.vending'},
        'version':{'package':'app.lokke.main','binary':'1.1.0','js':'1.1.0'},
        'platform':{'isAndroid':True,'isIOS':False,'isTV':False,'isWeb':False,'isMobile':True,'isWebTV':False,'isElectron':False}},
        'appFocusTime':0,'playerActive':False,'playDuration':0,'devMode':True,'hasAddon':True,
        'castConnected':False,'package':'app.lokke.main','version':'1.1.0','process':'app',
        'firstAppStart':now-86400000,'lastAppStart':now,'ipLocation':None,'adblockEnabled':False,
        'proxy':{'supported':['ss','openvpn'],'engine':'openvpn','ssVersion':1,'enabled':False,'autoServer':True,'id':'fi-hel'},
        'iap':{'supported':True}}
    headers = {'user-agent':'okhttp/4.11.0','accept':'application/json','content-type':'application/json; charset=utf-8','accept-encoding':'gzip'}
    connector = TCPConnector(family=socket.AF_INET)
    async with ClientSession(connector=connector) as s:
        async with s.post(_LOKKE_PING_URL, json=body, headers=headers, timeout=ClientTimeout(total=15)) as r:
            d = await r.json()
            print(d.get('addonSig',''))

asyncio.run(get_sig())
" 2>/dev/null)

if [ -z "$SIG" ]; then
    echo "   [!] Auth token alınamadı!"
    exit 1
fi

echo "   [OK] Token alındı: ${SIG:0:20}..."
echo ">>> Kanallar paralel işleniyor..."

resolve_channel() {
    local extinf="$1"
    local vavoo_url="$2"
    local sig="$3"

    name=$(echo "$extinf" | sed 's/.*,//' | tr -d '\r')
    group=$(echo "$extinf" | grep -oP 'group-title="\K[^"]+')
    safe_name=$(echo "$name" | sed 's/[^a-zA-Z0-9._-]/_/g')

    resolved=$(python3 -c "
import asyncio, socket
from aiohttp import ClientSession, ClientTimeout, TCPConnector

async def resolve(url, sig):
    headers = {
        'user-agent': 'MediaHubMX/2',
        'accept': 'application/json',
        'content-type': 'application/json; charset=utf-8',
        'accept-encoding': 'gzip',
        'mediahubmx-signature': sig,
    }
    body = {'language': 'de', 'region': 'AT', 'url': url, 'clientVersion': '3.0.2'}
    connector = TCPConnector(family=socket.AF_INET)
    async with ClientSession(connector=connector) as s:
        async with s.post('https://vavoo.to/mediahubmx-resolve.json', json=body, headers=headers, timeout=ClientTimeout(total=10)) as r:
            if r.status == 200:
                d = await r.json()
                if isinstance(d, list) and d and d[0].get('url'):
                    print(d[0]['url'])
                elif isinstance(d, dict) and d.get('url'):
                    print(d['url'])

asyncio.run(resolve('$vavoo_url', '$sig'))
" 2>/dev/null)

    if [ -n "$resolved" ]; then
        printf '#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-STREAM-INF:BANDWIDTH=1280000\n%s\n' "$resolved" > "playlist/${safe_name}.m3u8"
        echo "#EXTINF:-1 group-title=\"${group}\",${name}" >> playlist/vavoo_playlist.m3u
        echo "TUNNEL_URL/playlist/${safe_name}.m3u8" >> playlist/vavoo_playlist.m3u
        echo "   [OK] [$group] $name"
    else
        echo "   [!] $name başarısız"
    fi
}

export -f resolve_channel

extinf=""
while IFS= read -r line; do
    if [[ "$line" == "#EXTINF"* ]]; then
        extinf="$line"
    elif [[ "$line" == "https://vavoo.to"* ]]; then
        resolve_channel "$extinf" "$line" "$SIG" &
        if (( $(jobs -r | wc -l) >= 30 )); then
            wait
        fi
    fi
done < /sdcard/Download/vavoo_kanallar.m3u

wait
echo ">>> Vavoo tamamlandı."
